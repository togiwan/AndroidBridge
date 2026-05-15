import AndroidBridgeCore
import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class WirelessTransferStore {
    var selectedMode: WirelessTransferMode = .browser
    var browserSession: WirelessTransferSession?
    var browserURL: URL?
    var browserStatusMessage = "Start a Browser Transfer session to send files over Wi-Fi."
    var sharedItems: [SharedDownloadItem] = []
    var receivedUploads: [ReceivedUploadRecord] = []
    var adbWirelessStatusMessage = "Scan for wireless debugging devices or connect manually."
    var adbPairingAddress = ""
    var adbPairingCode = ""
    var adbConnectionAddress = ""
    var discoveredADBServices: [ADBWirelessService] = []

    private let browserServer = WirelessHTTPServer()
    private let adbWirelessClient = ADBWirelessClient()
    private let adbDiscovery = ADBWirelessDiscovery()
    private var browserTimeoutTask: Task<Void, Never>?
    private var generatedArchiveURLs: Set<URL> = []

    var isBrowserSessionRunning: Bool {
        browserSession != nil
    }

    func startBrowserSession() {
        guard let receiveFolder = pickReceiveFolder() else {
            return
        }

        let session = WirelessTransferSession(receiveFolder: receiveFolder)
        browserSession = session
        sharedItems = []
        receivedUploads = []

        do {
            browserURL = try browserServer.start(session: session)
            browserServer.setUploadHandler { [weak self] filename, data in
                Task { @MainActor in
                    self?.saveUploadedFile(filename: filename, data: data)
                }
            }
            restartBrowserTimeout()
            browserStatusMessage = "Browser Transfer session is ready."
        } catch {
            browserSession = nil
            browserURL = nil
            browserStatusMessage = "Could not start Browser Transfer: \(error.localizedDescription)"
        }
    }

    func stopBrowserSession() {
        browserTimeoutTask?.cancel()
        browserTimeoutTask = nil
        browserServer.setUploadHandler(nil)
        browserServer.stop()
        deleteGeneratedArchives()
        browserSession = nil
        browserURL = nil
        sharedItems = []
        receivedUploads = []
        browserStatusMessage = "Browser Transfer session stopped."
    }

    func addSharedFiles() {
        guard let session = browserSession else {
            browserStatusMessage = "Start a Browser Transfer session first."
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add Files"

        guard panel.runModal() == .OK else {
            return
        }

        let items = panel.urls.map { url in
            SharedDownloadItem(url: url, kind: .file, byteCount: fileSize(url))
        }
        session.addSharedItems(items)
        sharedItems = session.sharedItems
    }

    func addSharedFolder() {
        guard let session = browserSession else {
            browserStatusMessage = "Start a Browser Transfer session first."
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add Folders"

        guard panel.runModal() == .OK else {
            return
        }

        let selectedURLs = panel.urls
        browserStatusMessage = "Preparing folder ZIP archives..."

        Task {
            var items: [SharedDownloadItem] = []

            for url in selectedURLs {
                let folderItem = SharedDownloadItem(url: url, kind: .folder, byteCount: nil)
                do {
                    let archiveURL = try await WirelessZipArchive.createArchive(for: folderItem)
                    let archiveItem = SharedDownloadItem(
                        id: folderItem.id,
                        url: archiveURL,
                        kind: .file,
                        byteCount: fileSize(archiveURL)
                    )
                    generatedArchiveURLs.insert(archiveURL)
                    items.append(archiveItem)
                } catch {
                    browserStatusMessage = "Could not prepare \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }

            session.addSharedItems(items)
            sharedItems = session.sharedItems
            if !items.isEmpty {
                browserStatusMessage = "Prepared \(items.count) folder ZIP archive(s)."
            }
        }
    }

    func removeSharedItems(ids: Set<SharedDownloadItem.ID>) {
        guard let session = browserSession else {
            return
        }

        let removedItems = sharedItems.filter { ids.contains($0.id) }
        deleteGeneratedArchives(for: removedItems)
        ids.forEach { session.removeSharedItem(id: $0) }
        sharedItems = session.sharedItems
    }

    func clearSharedItems() {
        deleteGeneratedArchives(for: sharedItems)
        browserSession?.clearSharedItems()
        sharedItems = []
    }

    func pairADBWireless() async {
        do {
            try await adbWirelessClient.pair(address: adbPairingAddress, code: adbPairingCode)
            if adbConnectionAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                adbWirelessStatusMessage = "Paired. Enter the connection address, then connect."
            } else {
                try await adbWirelessClient.connect(address: adbConnectionAddress)
                adbWirelessStatusMessage = "Paired and connected. Go to USB Transfer and refresh devices."
            }
        } catch {
            adbWirelessStatusMessage = error.localizedDescription
        }
    }

    func connectADBWireless() async {
        do {
            try await adbWirelessClient.connect(address: adbConnectionAddress)
            adbWirelessStatusMessage = "Connected. Go to USB Transfer and refresh devices."
        } catch {
            adbWirelessStatusMessage = error.localizedDescription
        }
    }

    func disconnectADBWireless() async {
        do {
            try await adbWirelessClient.disconnect(address: adbConnectionAddress)
            adbWirelessStatusMessage = "Disconnected."
        } catch {
            adbWirelessStatusMessage = error.localizedDescription
        }
    }

    func scanADBWireless() {
        adbWirelessStatusMessage = "Scanning for wireless debugging devices..."
        adbDiscovery.start { [weak self] services in
            Task { @MainActor in
                self?.discoveredADBServices = services
                self?.adbWirelessStatusMessage = services.isEmpty
                    ? "No wireless debugging devices found yet."
                    : "Found \(services.count) wireless debugging service(s)."
            }
        }
    }

    func stopADBWirelessScan() {
        adbDiscovery.stop()
        discoveredADBServices = []
        adbWirelessStatusMessage = "Scan stopped."
    }

    private func saveUploadedFile(filename: String, data: Data) {
        guard let session = browserSession else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: session.receiveFolder,
                withIntermediateDirectories: true
            )

            let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: session.receiveFolder.path)) ?? [])
            let destination = WirelessUploadDestination.destination(
                originalFilename: filename,
                receiveFolder: session.receiveFolder,
                existingFilenames: existing
            )
            try data.write(to: destination, options: .atomic)
            receivedUploads.insert(
                ReceivedUploadRecord(fileURL: destination, byteCount: data.count, receivedAt: Date()),
                at: 0
            )
            restartBrowserTimeout()
            browserStatusMessage = "Received \(destination.lastPathComponent)."
        } catch {
            browserStatusMessage = "Could not save upload: \(error.localizedDescription)"
        }
    }

    func revealReceivedUpload(_ upload: ReceivedUploadRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([upload.fileURL])
    }

    private func restartBrowserTimeout() {
        browserTimeoutTask?.cancel()
        browserTimeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30 * 60))
            await MainActor.run {
                self?.stopBrowserSession()
                self?.browserStatusMessage = "Browser Transfer session stopped after 30 minutes."
            }
        }
    }

    private func deleteGeneratedArchives(for items: [SharedDownloadItem]? = nil) {
        let urlsToDelete: Set<URL>
        if let items {
            urlsToDelete = Set(items.map(\.url)).intersection(generatedArchiveURLs)
        } else {
            urlsToDelete = generatedArchiveURLs
        }

        urlsToDelete.forEach { url in
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            generatedArchiveURLs.remove(url)
        }
    }

    private func pickReceiveFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose where AndroidBridge should save files sent from your phone."
        panel.prompt = "Use Folder"
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func fileSize(_ url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return nil
        }
        return size.int64Value
    }
}
