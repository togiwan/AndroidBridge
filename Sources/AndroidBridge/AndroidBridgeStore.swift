import AndroidBridgeCore
import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class AndroidBridgeStore {
    var devices: [AndroidDevice] = []
    var selectedDeviceID: AndroidDevice.ID?
    var currentPath = "/sdcard/Download"
    var files: [AndroidFileItem] = []
    var selectedItemIDs: Set<AndroidFileItem.ID> = []
    var isBusy = false
    var statusMessage = "Connect an Android phone with USB debugging enabled."
    var transferProgress: Double?
    var transferDetailMessage: String?
    var isShowingSetupGuide = false
    var isShowingDonation = false

    private let client: ADBClient
    private var activeOperationTask: Task<Void, Error>?
    private var lastDownloadDirectory: URL?

    init(client: ADBClient = ADBClient()) {
        self.client = client
    }

    var selectedDevice: AndroidDevice? {
        devices.first { $0.id == selectedDeviceID }
    }

    var selectedItem: AndroidFileItem? {
        guard selectedItemIDs.count == 1, let selectedItemID = selectedItemIDs.first else {
            return nil
        }

        return files.first { $0.id == selectedItemID }
    }

    var selectedItems: [AndroidFileItem] {
        files.filter { selectedItemIDs.contains($0.id) }
    }

    var connectedDevices: [AndroidDevice] {
        devices.filter { $0.state == .device }
    }

    func refreshDevices() async {
        await runBusy("Refreshing devices...") { [self] in
            let loadedDevices = try await client.listDevices()
            devices = loadedDevices

            if selectedDeviceID == nil || !loadedDevices.contains(where: { $0.id == selectedDeviceID }) {
                selectedDeviceID = loadedDevices.first(where: { $0.state == .device })?.id
            }

            if selectedDevice?.state == .device {
                try await loadFiles()
            } else if loadedDevices.isEmpty {
                files = []
                statusMessage = "No devices found. Plug in your phone, unlock it, enable USB debugging, then approve the trust prompt."
            } else {
                files = []
                statusMessage = "Select an authorized device. Unauthorized phones need approval on the Android screen."
            }
        }
    }

    func open(_ item: AndroidFileItem) async {
        selectedItemIDs = [item.id]

        guard item.kind == .folder else {
            await preview(item)
            return
        }

        currentPath = item.path
        await refreshFiles()
    }

    func goUp() async {
        currentPath = AndroidPath.parent(of: currentPath)
        await refreshFiles()
    }

    func refreshFiles() async {
        await runBusy("Loading \(currentPath)...") { [self] in
            try await loadFiles()
        }
    }

    func cancelCurrentOperation() {
        guard isBusy else {
            return
        }

        transferDetailMessage = "Cancelling..."
        statusMessage = "Cancelling..."
        activeOperationTask?.cancel()
    }

    func downloadSelected() async {
        guard let selectedDeviceID, !selectedItems.isEmpty else {
            statusMessage = "Select one or more files or folders to download."
            return
        }

        let itemsToDownload = selectedItems

        guard let downloadDirectory = pickDownloadDirectory() else {
            return
        }

        lastDownloadDirectory = downloadDirectory

        guard FileManager.default.fileExists(atPath: downloadDirectory.path) else {
            statusMessage = "Could not find the selected download folder."
            return
        }

        let downloadTitle = AndroidSelectionSummary.downloadTitle(for: itemsToDownload)

        await runBusy("Downloading \(downloadTitle)...") { [self] in
            for (index, item) in itemsToDownload.enumerated() {
                let destination = LocalDownloadDestination.destination(
                    for: item,
                    downloadDirectory: downloadDirectory
                )
                let startedAt = Date()
                let displayName = AndroidSelectionSummary.progressTitle(
                    for: item,
                    index: index,
                    totalCount: itemsToDownload.count
                )

                transferProgress = item.kind == .file && item.size > 0 ? 0 : nil
                updateTransferDetail(for: displayName, progress: nil, estimate: nil, startedAt: startedAt)

                let monitorTask = startLocalTransferMonitor(
                    for: item,
                    displayName: displayName,
                    localFileURL: destination.file,
                    startedAt: startedAt
                )
                defer {
                    monitorTask?.cancel()
                }

                try Task.checkCancellation()
                try await client.pull(deviceID: selectedDeviceID, remotePath: item.path, to: destination.directory) { progress in
                    Task { @MainActor in
                        self.updateTransferDetail(for: displayName, progress: progress, estimate: nil, startedAt: startedAt)
                    }
                }
            }

            transferProgress = 1
            transferDetailMessage = nil
            statusMessage = AndroidSelectionSummary.completedMessage(
                for: itemsToDownload,
                directoryName: downloadDirectory.lastPathComponent
            )
        }
    }

    func uploadFile() async {
        guard let selectedDeviceID else {
            statusMessage = "Select a connected Android device first."
            return
        }

        let itemURLs = pickUploadItems()
        guard !itemURLs.isEmpty else {
            return
        }

        let uploadTitle = LocalUploadSelectionSummary.uploadTitle(for: itemURLs)

        await runBusy("Uploading \(uploadTitle)...") { [self] in
            for (index, itemURL) in itemURLs.enumerated() {
                let startedAt = Date()
                let displayName = LocalUploadSelectionSummary.progressTitle(
                    for: itemURL,
                    index: index,
                    totalCount: itemURLs.count
                )

                transferProgress = 0
                updateTransferDetail(for: displayName, verb: "Uploading", progress: nil, estimate: nil, startedAt: startedAt)

                try Task.checkCancellation()
                try await client.push(deviceID: selectedDeviceID, localURL: itemURL, to: currentPath) { progress in
                    Task { @MainActor in
                        self.updateTransferDetail(
                            for: displayName,
                            verb: "Uploading",
                            progress: progress,
                            estimate: nil,
                            startedAt: startedAt
                        )
                    }
                }
            }

            try await loadFiles()
            transferDetailMessage = nil
            statusMessage = LocalUploadSelectionSummary.completedMessage(for: itemURLs, remotePath: currentPath)
        }
    }

    private func preview(_ item: AndroidFileItem) async {
        guard let selectedDeviceID else {
            statusMessage = "Select a connected Android device first."
            return
        }

        let destination = LocalPreviewDestination.destination(for: item)

        await runBusy("Opening \(item.name)...") { [self] in
            try FileManager.default.createDirectory(
                at: destination.directory,
                withIntermediateDirectories: true
            )

            let startedAt = Date()
            transferProgress = item.size > 0 ? 0 : nil
            updateTransferDetail(for: item.name, progress: nil, estimate: nil, startedAt: startedAt)

            let monitorTask = startLocalTransferMonitor(
                for: item,
                displayName: item.name,
                localFileURL: destination.file,
                startedAt: startedAt
            )
            defer {
                monitorTask?.cancel()
            }

            try await client.pull(deviceID: selectedDeviceID, remotePath: item.path, to: destination.directory) { progress in
                Task { @MainActor in
                    self.updateTransferDetail(for: item.name, progress: progress, estimate: nil, startedAt: startedAt)
                }
            }

            NSWorkspace.shared.open(destination.file)
            statusMessage = "Opened \(item.name)."
        }
    }

    private func loadFiles() async throws {
        guard let selectedDeviceID else {
            files = []
            statusMessage = "Select a connected Android device."
            return
        }

        files = try await client.listFiles(deviceID: selectedDeviceID, path: currentPath)
        selectedItemIDs = []
        statusMessage = files.isEmpty ? "Folder is empty." : "Showing \(currentPath)."
    }

    private func runBusy(_ message: String, operation: @escaping () async throws -> Void) async {
        isBusy = true
        statusMessage = message

        let task = Task {
            try await operation()
        }
        activeOperationTask = task

        do {
            try await task.value
        } catch is CancellationError {
            statusMessage = "Operation cancelled."
        } catch {
            statusMessage = error.localizedDescription
        }

        activeOperationTask = nil
        isBusy = false
        transferProgress = nil
        transferDetailMessage = nil
    }

    private func pickUploadItems() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = "Choose files or folders to upload to the current Android folder."
        panel.prompt = "Upload"

        return panel.runModal() == .OK ? panel.urls : []
    }

    private func pickDownloadDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.message = "Choose where to save the selected Android items."
        panel.prompt = "Download Here"
        panel.directoryURL = lastDownloadDirectory ?? FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        ).first

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func startLocalTransferMonitor(
        for item: AndroidFileItem,
        displayName: String,
        localFileURL: URL,
        startedAt: Date
    ) -> Task<Void, Never>? {
        guard item.kind == .file, item.size > 0 else {
            return nil
        }

        return Task { [weak self] in
            while !Task.isCancelled {
                self?.updateTransferDetailFromLocalFile(
                    named: displayName,
                    localFileURL: localFileURL,
                    totalBytes: item.size,
                    startedAt: startedAt
                )

                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }

    private func updateTransferDetailFromLocalFile(
        named fileName: String,
        localFileURL: URL,
        totalBytes: Int64,
        startedAt: Date
    ) {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: localFileURL.path),
              let fileSize = attributes[.size] as? NSNumber else {
            updateTransferDetail(for: fileName, progress: nil, estimate: nil, startedAt: startedAt)
            return
        }

        if let modifiedAt = attributes[.modificationDate] as? Date, modifiedAt < startedAt.addingTimeInterval(-1) {
            updateTransferDetail(for: fileName, progress: nil, estimate: nil, startedAt: startedAt)
            return
        }

        let estimate = TransferProgressEstimate(
            bytesTransferred: fileSize.int64Value,
            totalBytes: totalBytes,
            elapsedSeconds: Date().timeIntervalSince(startedAt)
        )
        updateTransferDetail(for: fileName, progress: nil, estimate: estimate, startedAt: startedAt)
    }

    private func updateTransferDetail(
        for fileName: String,
        verb: String = "Downloading",
        progress: ADBTransferProgress?,
        estimate: TransferProgressEstimate?,
        startedAt: Date
    ) {
        let elapsed = max(0, Date().timeIntervalSince(startedAt))

        if let estimate, estimate.percent > 0 {
            transferProgress = estimate.fraction

            if let remainingSeconds = estimate.remainingSeconds {
                transferDetailMessage = "\(verb) \(fileName) - \(estimate.percent)% - about \(formatDuration(TimeInterval(remainingSeconds))) left"
            } else {
                transferDetailMessage = "Finishing \(fileName)..."
            }

            return
        }

        guard let progress else {
            if transferProgress == nil {
                transferProgress = nil
            }
            transferDetailMessage = "\(verb) \(fileName) - \(formatDuration(elapsed)) elapsed"
            return
        }

        let fraction = Double(progress.percent) / 100
        transferProgress = fraction

        if progress.percent > 0 && progress.percent < 100 {
            let estimatedTotal = elapsed / fraction
            let remaining = max(0, estimatedTotal - elapsed)
            transferDetailMessage = "\(verb) \(fileName) - \(progress.percent)% - about \(formatDuration(remaining)) left"
        } else if progress.percent >= 100 {
            transferDetailMessage = "Finishing \(fileName)..."
        } else {
            transferDetailMessage = "\(verb) \(fileName) - \(formatDuration(elapsed)) elapsed"
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))

        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        let remainingSeconds = seconds % 60

        if minutes < 60 {
            return remainingSeconds == 0 ? "\(minutes)m" : "\(minutes)m \(remainingSeconds)s"
        }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return remainingMinutes == 0 ? "\(hours)h" : "\(hours)h \(remainingMinutes)m"
    }
}
