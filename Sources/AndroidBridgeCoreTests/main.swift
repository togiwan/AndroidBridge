@testable import AndroidBridgeCore
import Darwin
import Foundation

@discardableResult
func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) -> Bool {
    if actual != expected {
        print("FAIL: \(message)")
        print("  actual:   \(actual)")
        print("  expected: \(expected)")
        return false
    }

    return true
}

var failures = 0

func check(_ passed: Bool) {
    if !passed {
        failures += 1
    }
}

func parsesConnectedUnauthorizedAndOfflineDevices() {
    let output = """
    List of devices attached
    R58N123ABC\tdevice
    emulator-5554\toffline
    ZX1G22B7QK\tunauthorized

    """

    let devices = ADBOutputParser.parseDevices(output)

    check(expectEqual(devices, [
        AndroidDevice(id: "R58N123ABC", state: .device),
        AndroidDevice(id: "emulator-5554", state: .offline),
        AndroidDevice(id: "ZX1G22B7QK", state: .unauthorized)
    ], "parse adb devices output"))
}

func parsesFileListingWithFoldersFilesAndSpaces() {
    let output = """
    drwxrwx--x 2 root sdcard_rw 4096 2026-05-03 10:42 Camera Roll
    -rw-rw---- 1 root sdcard_rw 7340032 2026-05-03 10:45 trip video.mp4
    """

    let items = ADBOutputParser.parseFileListing(output, parentPath: "/sdcard/Download")

    check(expectEqual(items, [
        AndroidFileItem(name: "Camera Roll", path: "/sdcard/Download/Camera Roll", kind: .folder, size: 4096),
        AndroidFileItem(name: "trip video.mp4", path: "/sdcard/Download/trip video.mp4", kind: .file, size: 7_340_032)
    ], "parse adb shell ls output"))
}

func joiningPathComponentsAvoidsDuplicateSlashes() {
    check(expectEqual(AndroidPath.join("/sdcard/Download", "Camera"), "/sdcard/Download/Camera", "join normal path"))
    check(expectEqual(AndroidPath.join("/sdcard/Download/", "Camera"), "/sdcard/Download/Camera", "join trailing slash path"))
    check(expectEqual(AndroidPath.join("/", "sdcard"), "/sdcard", "join root path"))
}

func parentPathStopsAtRoot() {
    check(expectEqual(AndroidPath.parent(of: "/sdcard/Download"), "/sdcard", "parent of nested path"))
    check(expectEqual(AndroidPath.parent(of: "/sdcard"), "/", "parent of top-level path"))
    check(expectEqual(AndroidPath.parent(of: "/"), "/", "parent of root path"))
}

func parsesADBTransferProgressPercentages() {
    check(expectEqual(
        ADBTransferProgressParser.parse("[ 42%] /sdcard/Download/video.mp4"),
        ADBTransferProgress(percent: 42),
        "parse spaced adb transfer progress"
    ))
    check(expectEqual(
        ADBTransferProgressParser.parse("\r[100%] /sdcard/Download/video.mp4"),
        ADBTransferProgress(percent: 100),
        "parse carriage-return adb transfer progress"
    ))
    check(expectEqual(
        ADBTransferProgressParser.parse("/sdcard/Download/video.mp4: 1 file pulled, 0 skipped. 25.1 MB/s"),
        nil,
        "ignore adb transfer summary"
    ))
}

func estimatesProgressFromTransferredBytes() {
    check(expectEqual(
        TransferProgressEstimate(bytesTransferred: 250, totalBytes: 1_000, elapsedSeconds: 2).percent,
        25,
        "estimate percent from bytes"
    ))
    check(expectEqual(
        TransferProgressEstimate(bytesTransferred: 250, totalBytes: 1_000, elapsedSeconds: 2).remainingSeconds,
        6,
        "estimate remaining seconds from transfer rate"
    ))
    check(expectEqual(
        TransferProgressEstimate(bytesTransferred: 1_500, totalBytes: 1_000, elapsedSeconds: 2).fraction,
        1,
        "clamp progress fraction"
    ))
}

func setupGuideMentionsRequiredSetupPieces() {
    let guideText = AndroidBridgeSetupGuide.sections
        .flatMap { section in
            [section.title, section.body]
                + section.steps.map(\.title)
                + section.steps.map(\.body)
                + section.steps.compactMap(\.command)
        }
        .joined(separator: "\n")

    check(expectEqual(guideText.contains("brew install android-platform-tools"), true, "guide includes Homebrew platform-tools install"))
    check(expectEqual(guideText.contains("USB debugging"), true, "guide includes USB debugging"))
    check(expectEqual(guideText.contains("adb devices"), true, "guide includes adb devices verification"))
    check(expectEqual(guideText.contains("RSA"), true, "guide includes Android trust prompt"))
}

func resolvesADBFromCommonMacInstallPathsBeforeEnvFallback() {
    let command = ADBExecutableResolver.resolve { path in
        path == "/opt/homebrew/bin/adb"
    }

    check(expectEqual(command.executable, "/opt/homebrew/bin/adb", "resolve Homebrew adb executable"))
    check(expectEqual(command.leadingArguments, [], "resolved direct adb has no leading env argument"))
}

func fallsBackToEnvWhenADBIsNotInKnownLocations() {
    let command = ADBExecutableResolver.resolve { _ in false }

    check(expectEqual(command.executable, "/usr/bin/env", "fallback uses env executable"))
    check(expectEqual(command.leadingArguments, ["adb"], "fallback asks env to locate adb"))
}

func donationInfoUsesUSDTTRC20Address() {
    check(expectEqual(AndroidBridgeDonationInfo.asset, "USDT", "donation asset"))
    check(expectEqual(AndroidBridgeDonationInfo.network, "TRC20", "donation network"))
    check(expectEqual(AndroidBridgeDonationInfo.address, "TLXKfMgVzX1QYxtU9p5pidoNW2HiKjG6He", "donation address"))
    check(expectEqual(AndroidBridgeDonationInfo.warning.contains("TRC20"), true, "donation warning includes network"))
}

func previewDestinationUsesDedicatedTemporaryFolder() {
    let baseURL = URL(fileURLWithPath: "/tmp")
    let item = AndroidFileItem(
        name: "sample image.jpg",
        path: "/sdcard/Download/sample image.jpg",
        kind: .file,
        size: 1024
    )

    let destination = LocalPreviewDestination.destination(for: item, temporaryDirectory: baseURL)

    check(expectEqual(destination.directory.path, "/tmp/AndroidBridgePreviews", "preview directory"))
    check(expectEqual(destination.file.path, "/tmp/AndroidBridgePreviews/sample image.jpg", "preview file path"))
}

func downloadDestinationUsesChosenFolderAndItemName() {
    let folderURL = URL(fileURLWithPath: "/Users/me/Desktop")
    let item = AndroidFileItem(
        name: "holiday video.mp4",
        path: "/sdcard/Download/holiday video.mp4",
        kind: .file,
        size: 2048
    )

    let destination = LocalDownloadDestination.destination(for: item, downloadDirectory: folderURL)

    check(expectEqual(destination.directory.path, "/Users/me/Desktop", "download destination directory"))
    check(expectEqual(destination.file.path, "/Users/me/Desktop/holiday video.mp4", "download destination file path"))
}

func selectionSummaryDescribesSingleAndMultipleItems() {
    let photo = AndroidFileItem(name: "photo.jpg", path: "/sdcard/Download/photo.jpg", kind: .file, size: 10)
    let folder = AndroidFileItem(name: "Camera", path: "/sdcard/Download/Camera", kind: .folder, size: 0)

    check(expectEqual(AndroidSelectionSummary.downloadTitle(for: [photo]), "photo.jpg", "single selection title"))
    check(expectEqual(AndroidSelectionSummary.downloadTitle(for: [photo, folder]), "2 items", "multi selection title"))
    check(expectEqual(AndroidSelectionSummary.progressTitle(for: photo, index: 0, totalCount: 1), "photo.jpg", "single progress title"))
    check(expectEqual(AndroidSelectionSummary.progressTitle(for: folder, index: 1, totalCount: 2), "2/2 Camera", "multi progress title"))
    check(expectEqual(AndroidSelectionSummary.completedMessage(for: [photo], directoryName: "Desktop"), "Downloaded photo.jpg to Desktop.", "single completion message"))
    check(expectEqual(AndroidSelectionSummary.completedMessage(for: [photo, folder], directoryName: "Desktop"), "Downloaded 2 items to Desktop.", "multi completion message"))
}

func uploadSelectionSummaryDescribesSingleAndMultipleURLs() {
    let fileURL = URL(fileURLWithPath: "/Users/me/Desktop/photo.jpg")
    let folderURL = URL(fileURLWithPath: "/Users/me/Desktop/Camera")

    check(expectEqual(LocalUploadSelectionSummary.uploadTitle(for: [fileURL]), "photo.jpg", "single upload title"))
    check(expectEqual(LocalUploadSelectionSummary.uploadTitle(for: [fileURL, folderURL]), "2 items", "multi upload title"))
    check(expectEqual(LocalUploadSelectionSummary.progressTitle(for: fileURL, index: 0, totalCount: 1), "photo.jpg", "single upload progress title"))
    check(expectEqual(LocalUploadSelectionSummary.progressTitle(for: folderURL, index: 1, totalCount: 2), "2/2 Camera", "multi upload progress title"))
    check(expectEqual(LocalUploadSelectionSummary.completedMessage(for: [fileURL], remotePath: "/sdcard/Download"), "Uploaded photo.jpg to /sdcard/Download.", "single upload completion message"))
    check(expectEqual(LocalUploadSelectionSummary.completedMessage(for: [fileURL, folderURL], remotePath: "/sdcard/Download"), "Uploaded 2 items to /sdcard/Download.", "multi upload completion message"))
}

func wirelessTokenCreatesUsableURLTokenAndPIN() {
    let token = WirelessTransferToken(urlToken: "abcdef1234567890", pin: "123456")

    check(expectEqual(token.urlToken, "abcdef1234567890", "wireless token keeps url token"))
    check(expectEqual(token.pin, "123456", "wireless token keeps pin"))
    check(expectEqual(WirelessTransferToken.isValidPIN("123456"), true, "six digit pin is valid"))
    check(expectEqual(WirelessTransferToken.isValidPIN("12345"), false, "short pin is invalid"))
    check(expectEqual(WirelessTransferToken.isValidPIN("abcdef"), false, "non numeric pin is invalid"))
}

func sharedDownloadItemUsesFriendlyMetadata() {
    let fileURL = URL(fileURLWithPath: "/Users/me/Desktop/photo.jpg")
    let folderURL = URL(fileURLWithPath: "/Users/me/Desktop/Camera", isDirectory: true)

    let file = SharedDownloadItem(url: fileURL, kind: .file, byteCount: 1024)
    let folder = SharedDownloadItem(url: folderURL, kind: .folder, byteCount: nil)

    check(expectEqual(file.name, "photo.jpg", "file shared item name"))
    check(expectEqual(file.downloadName, "photo.jpg", "file download name"))
    check(expectEqual(folder.name, "Camera", "folder shared item name"))
    check(expectEqual(folder.downloadName, "Camera.zip", "folder download name"))
}

func uploadDestinationAutoRenamesCollisionsInsideReceiveFolder() {
    let receiveFolder = URL(fileURLWithPath: "/tmp/AndroidBridgeReceive", isDirectory: true)
    let existingNames: Set<String> = ["photo.jpg", "photo 2.jpg"]

    let destination = WirelessUploadDestination.destination(
        originalFilename: "photo.jpg",
        receiveFolder: receiveFolder,
        existingFilenames: existingNames
    )

    check(expectEqual(destination.lastPathComponent, "photo 3.jpg", "upload collision is auto-renamed"))
    check(expectEqual(destination.deletingLastPathComponent().path, receiveFolder.path, "upload stays in receive folder"))
}

func wirelessSessionAddsAndClearsSharedItems() {
    let session = WirelessTransferSession(
        token: WirelessTransferToken(urlToken: "abcdef1234567890", pin: "123456"),
        receiveFolder: URL(fileURLWithPath: "/tmp/AndroidBridgeReceive", isDirectory: true)
    )
    let fileURL = URL(fileURLWithPath: "/Users/me/Desktop/photo.jpg")

    session.addSharedItems([SharedDownloadItem(url: fileURL, kind: .file, byteCount: 1024)])
    check(expectEqual(session.sharedItems.count, 1, "session adds shared item"))

    session.clearSharedItems()
    check(expectEqual(session.sharedItems.isEmpty, true, "session clears shared items"))
}

func wirelessHTMLRendererEscapesNamesAndShowsActions() {
    let item = SharedDownloadItem(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        url: URL(fileURLWithPath: "/Users/me/Desktop/a&b.jpg"),
        kind: .file,
        byteCount: 42
    )

    let html = WirelessHTMLRenderer.pageHTML(sharedItems: [item], authenticated: true)

    check(expectEqual(html.contains("Send to Mac"), true, "html includes send section"))
    check(expectEqual(html.contains("Get from Mac"), true, "html includes get section"))
    check(expectEqual(html.contains("a&amp;b.jpg"), true, "html escapes item name"))
    check(expectEqual(html.contains("/download/11111111-1111-1111-1111-111111111111"), true, "html links shared item"))
}

@MainActor
func commandFailureMapsUnauthorizedDeviceToHelpfulMessage() async {
    let runner = FakeProcessRunner(results: [
        ProcessResult(
            stdout: "",
            stderr: "error: device unauthorized.\nThis adb server's $ADB_VENDOR_KEYS is not set",
            exitCode: 1
        )
    ])
    let client = ADBClient(command: ADBCommand(executable: "/usr/bin/adb"), runner: runner)

    do {
        _ = try await client.listFiles(deviceID: "phone-1", path: "/sdcard/Download")
        print("FAIL: listFiles should throw for unauthorized devices")
        failures += 1
    } catch {
        check(expectEqual(
            error.localizedDescription,
            "This phone is not authorized yet. Unlock it, approve the USB debugging RSA prompt, then refresh devices.",
            "map unauthorized adb error to helpful message"
        ))
    }
}

@MainActor
func pushStreamsProgressUpdates() async throws {
    let runner = FakeProcessRunner(
        results: [
            ProcessResult(stdout: "", stderr: "", exitCode: 0)
        ],
        streamingChunks: ["[ 42%] /Users/me/video.mp4"]
    )
    let client = ADBClient(command: ADBCommand(executable: "/usr/bin/adb"), runner: runner)
    let progressRecorder = ProgressRecorder()

    try await client.push(
        deviceID: "phone-1",
        localURL: URL(fileURLWithPath: "/Users/me/video.mp4"),
        to: "/sdcard/Download"
    ) { progress in
        progressRecorder.append(progress)
    }

    check(expectEqual(progressRecorder.values, [ADBTransferProgress(percent: 42)], "push streams transfer progress"))
    let recordedRuns = await runner.recordedRuns
    check(expectEqual(recordedRuns.first?.arguments, [
        "-s",
        "phone-1",
        "push",
        "/Users/me/video.mp4",
        "/sdcard/Download"
    ], "push runs adb with expected arguments"))
}

@MainActor
func processRunnerTerminatesProcessWhenTaskIsCancelled() async {
    let runner = FoundationProcessRunner()
    let startedAt = Date()
    let task = Task {
        try await runner.run("/bin/sleep", arguments: ["5"])
    }

    try? await Task.sleep(for: .milliseconds(200))
    task.cancel()

    do {
        _ = try await task.value
        print("FAIL: cancelled process runner task should throw")
        failures += 1
    } catch is CancellationError {
        let elapsed = Date().timeIntervalSince(startedAt)
        check(expectEqual(elapsed < 2, true, "cancelled process exits quickly"))
    } catch {
        print("FAIL: cancelled process runner task threw unexpected error: \(error)")
        failures += 1
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var progressValues: [ADBTransferProgress] = []

    var values: [ADBTransferProgress] {
        lock.lock()
        defer { lock.unlock() }
        return progressValues
    }

    func append(_ progress: ADBTransferProgress) {
        lock.lock()
        progressValues.append(progress)
        lock.unlock()
    }
}

private actor FakeProcessRunner: ProcessRunning {
    struct RecordedRun: Equatable {
        let executable: String
        let arguments: [String]
        let isStreaming: Bool
    }

    private var results: [ProcessResult]
    private let streamingChunks: [String]
    private var runs: [RecordedRun] = []

    init(results: [ProcessResult], streamingChunks: [String] = []) {
        self.results = results
        self.streamingChunks = streamingChunks
    }

    var recordedRuns: [RecordedRun] {
        runs
    }

    func run(_ executable: String, arguments: [String]) async throws -> ProcessResult {
        runs.append(RecordedRun(executable: executable, arguments: arguments, isStreaming: false))
        let result = results.removeFirst()
        return result
    }

    func runStreaming(
        _ executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        runs.append(RecordedRun(executable: executable, arguments: arguments, isStreaming: true))
        let result = results.removeFirst()

        streamingChunks.forEach(onOutput)
        return result
    }
}

parsesConnectedUnauthorizedAndOfflineDevices()
parsesFileListingWithFoldersFilesAndSpaces()
joiningPathComponentsAvoidsDuplicateSlashes()
parentPathStopsAtRoot()
parsesADBTransferProgressPercentages()
estimatesProgressFromTransferredBytes()
setupGuideMentionsRequiredSetupPieces()
resolvesADBFromCommonMacInstallPathsBeforeEnvFallback()
fallsBackToEnvWhenADBIsNotInKnownLocations()
donationInfoUsesUSDTTRC20Address()
previewDestinationUsesDedicatedTemporaryFolder()
downloadDestinationUsesChosenFolderAndItemName()
selectionSummaryDescribesSingleAndMultipleItems()
uploadSelectionSummaryDescribesSingleAndMultipleURLs()
wirelessTokenCreatesUsableURLTokenAndPIN()
sharedDownloadItemUsesFriendlyMetadata()
uploadDestinationAutoRenamesCollisionsInsideReceiveFolder()
wirelessSessionAddsAndClearsSharedItems()
wirelessHTMLRendererEscapesNamesAndShowsActions()
await commandFailureMapsUnauthorizedDeviceToHelpfulMessage()
try await pushStreamsProgressUpdates()
await processRunnerTerminatesProcessWhenTaskIsCancelled()

if failures > 0 {
    print("AndroidBridgeCoreTests failed: \(failures)")
    exit(1)
}

print("AndroidBridgeCoreTests passed")
