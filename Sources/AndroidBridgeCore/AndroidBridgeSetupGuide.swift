import Foundation

public struct SetupGuideSection: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let steps: [SetupGuideStep]

    public init(id: String, title: String, body: String, steps: [SetupGuideStep]) {
        self.id = id
        self.title = title
        self.body = body
        self.steps = steps
    }
}

public struct SetupGuideStep: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let command: String?

    public init(id: String, title: String, body: String, command: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.command = command
    }
}

public enum AndroidBridgeSetupGuide {
    public static let platformToolsURL = URL(string: "https://developer.android.com/tools/releases/platform-tools")!
    public static let adbDocsURL = URL(string: "https://developer.android.com/tools/adb")!

    public static let sections: [SetupGuideSection] = [
        SetupGuideSection(
            id: "platform-tools",
            title: "1. Install Android Platform-Tools on your Mac",
            body: "AndroidBridge connects to your phone through ADB. ADB is included in Google's Android SDK Platform-Tools package.",
            steps: [
                SetupGuideStep(
                    id: "homebrew",
                    title: "Recommended: install with Homebrew",
                    body: "Open Terminal and run this command. After installation finishes, reopen AndroidBridge.",
                    command: "brew install android-platform-tools"
                ),
                SetupGuideStep(
                    id: "official-zip",
                    title: "Alternative: use Google's official zip",
                    body: "Download Android SDK Platform-Tools for Mac, unzip it, and keep the extracted platform-tools folder somewhere safe. You can test it from Terminal by going into that folder and running ./adb devices."
                ),
                SetupGuideStep(
                    id: "verify-adb",
                    title: "Verify the installation",
                    body: "Run adb version or adb devices in Terminal. If the command is not found, Platform-Tools is not available in your PATH.",
                    command: "adb devices"
                )
            ]
        ),
        SetupGuideSection(
            id: "phone-debugging",
            title: "2. Enable USB debugging on the phone",
            body: "USB debugging allows your Mac to communicate with the Android phone through ADB. Do this while the phone is unlocked.",
            steps: [
                SetupGuideStep(
                    id: "developer-options",
                    title: "Enable Developer Options",
                    body: "On the phone, open Settings > About phone. Tap Build number several times, usually 7 times. Enter your PIN if asked. Android should show a message saying developer options are enabled."
                ),
                SetupGuideStep(
                    id: "enable-usb-debugging",
                    title: "Turn on USB debugging",
                    body: "Open Developer Options in Settings. Depending on your Android version, it may be under System > Advanced > Developer Options. Turn on the USB debugging switch."
                ),
                SetupGuideStep(
                    id: "security-note",
                    title: "Security note",
                    body: "Only enable USB debugging for computers you trust. You can turn it off again from Developer Options when you are done."
                )
            ]
        ),
        SetupGuideSection(
            id: "connect",
            title: "3. Connect the phone and approve access",
            body: "The first time you connect, Android asks whether this Mac should be allowed to debug the phone.",
            steps: [
                SetupGuideStep(
                    id: "cable",
                    title: "Use a USB cable that supports data",
                    body: "Some USB cables only charge. If the phone does not appear, try a different cable or USB port."
                ),
                SetupGuideStep(
                    id: "rsa",
                    title: "Approve the RSA trust prompt",
                    body: "Unlock the phone. If you see an 'Allow USB debugging?' or RSA fingerprint prompt, choose Allow. On your own Mac, you can also check 'Always allow from this computer'."
                ),
                SetupGuideStep(
                    id: "check-state",
                    title: "Check the connection",
                    body: "Run adb devices in Terminal. If the device line ends with device, it is ready. If it says unauthorized, approve the prompt on the phone. If it says offline, unplug and reconnect the cable or restart the phone.",
                    command: "adb devices"
                )
            ]
        ),
        SetupGuideSection(
            id: "use-app",
            title: "4. Transfer files with AndroidBridge",
            body: "When the device is ready, click Refresh Devices in AndroidBridge. The app opens /sdcard/Download by default.",
            steps: [
                SetupGuideStep(
                    id: "download",
                    title: "Download from Android to Mac",
                    body: "Select one or more files or folders on the phone, click Download To, then choose where to save them on your Mac."
                ),
                SetupGuideStep(
                    id: "upload",
                    title: "Upload from Mac to Android",
                    body: "Open the target folder on the phone, click Upload, and choose one or more files or folders from your Mac. The selected items are sent to the currently open Android folder."
                )
            ]
        )
    ]
}
