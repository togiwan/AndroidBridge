import Foundation

public struct ADBCommand: Equatable, Sendable {
    public let executable: String
    public let leadingArguments: [String]

    public init(executable: String, leadingArguments: [String] = []) {
        self.executable = executable
        self.leadingArguments = leadingArguments
    }
}

public enum ADBExecutableResolver {
    public static let knownMacPaths = [
        "/opt/homebrew/bin/adb",
        "/usr/local/bin/adb",
        "/opt/homebrew/Caskroom/android-platform-tools/latest/platform-tools/adb",
        "/usr/local/Caskroom/android-platform-tools/latest/platform-tools/adb"
    ]

    public static func resolve(fileExists: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) -> ADBCommand {
        if let adbPath = knownMacPaths.first(where: fileExists) {
            return ADBCommand(executable: adbPath)
        }

        return ADBCommand(executable: "/usr/bin/env", leadingArguments: ["adb"])
    }
}
