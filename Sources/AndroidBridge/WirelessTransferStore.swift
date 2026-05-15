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
    var adbWirelessStatusMessage = "Scan for wireless debugging devices or connect manually."

    private let browserServer = WirelessHTTPServer()

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

        do {
            browserURL = try browserServer.start(session: session)
            browserServer.setUploadHandler { [weak self] filename, data in
                Task { @MainActor in
                    self?.saveUploadedFile(filename: filename, data: data)
                }
            }
            browserStatusMessage = "Browser Transfer session is ready."
        } catch {
            browserSession = nil
            browserURL = nil
            browserStatusMessage = "Could not start Browser Transfer: \(error.localizedDescription)"
        }
    }

    func stopBrowserSession() {
        browserServer.setUploadHandler(nil)
        browserServer.stop()
        browserSession = nil
        browserURL = nil
        sharedItems = []
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

        let items = panel.urls.map { url in
            SharedDownloadItem(url: url, kind: .folder, byteCount: nil)
        }
        session.addSharedItems(items)
        sharedItems = session.sharedItems
    }

    func removeSharedItems(ids: Set<SharedDownloadItem.ID>) {
        guard let session = browserSession else {
            return
        }

        ids.forEach { session.removeSharedItem(id: $0) }
        sharedItems = session.sharedItems
    }

    func clearSharedItems() {
        browserSession?.clearSharedItems()
        sharedItems = []
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
            browserStatusMessage = "Received \(destination.lastPathComponent)."
        } catch {
            browserStatusMessage = "Could not save upload: \(error.localizedDescription)"
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
