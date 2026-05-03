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

if failures > 0 {
    print("AndroidBridgeCoreTests failed: \(failures)")
    exit(1)
}

print("AndroidBridgeCoreTests passed")
