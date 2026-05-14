import Foundation

public enum ADBClientError: LocalizedError {
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let message):
            message
        }
    }
}

public struct ADBClient: Sendable {
    private let command: ADBCommand
    private let runner: ProcessRunning

    public init(command: ADBCommand = ADBExecutableResolver.resolve(), runner: ProcessRunning = FoundationProcessRunner()) {
        self.command = command
        self.runner = runner
    }

    public func listDevices() async throws -> [AndroidDevice] {
        let result = try await runADB(arguments: ["devices"])
        return ADBOutputParser.parseDevices(result.stdout)
    }

    public func listFiles(deviceID: String, path: String) async throws -> [AndroidFileItem] {
        let result = try await runADB(arguments: [
            "-s",
            deviceID,
            "shell",
            "ls -la \(AndroidPath.shellQuoted(path))"
        ])
        return ADBOutputParser.parseFileListing(result.stdout, parentPath: path)
    }

    public func pull(
        deviceID: String,
        remotePath: String,
        to localURL: URL,
        onProgress: (@Sendable (ADBTransferProgress) -> Void)? = nil
    ) async throws {
        _ = try await runADBStreaming(arguments: ["-s", deviceID, "pull", remotePath, localURL.path]) { text in
            guard let progress = ADBTransferProgressParser.parse(text) else {
                return
            }

            onProgress?(progress)
        }
    }

    public func push(
        deviceID: String,
        localURL: URL,
        to remoteFolder: String,
        onProgress: (@Sendable (ADBTransferProgress) -> Void)? = nil
    ) async throws {
        let arguments = ["-s", deviceID, "push", localURL.path, remoteFolder]

        if let onProgress {
            _ = try await runADBStreaming(arguments: arguments) { text in
                guard let progress = ADBTransferProgressParser.parse(text) else {
                    return
                }

                onProgress(progress)
            }
        } else {
            _ = try await runADB(arguments: arguments)
        }
    }

    private func runADB(arguments: [String]) async throws -> ProcessResult {
        let result = try await runner.run(command.executable, arguments: command.leadingArguments + arguments)

        guard result.exitCode == 0 else {
            let message = helpfulErrorMessage(
                for: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: result.exitCode
            )
            throw ADBClientError.commandFailed(message.isEmpty ? "adb exited with code \(result.exitCode)" : message)
        }

        return result
    }

    private func runADBStreaming(
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        let result = try await runner.runStreaming(command.executable, arguments: command.leadingArguments + arguments, onOutput: onOutput)

        guard result.exitCode == 0 else {
            let message = helpfulErrorMessage(
                for: result.stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                exitCode: result.exitCode
            )
            throw ADBClientError.commandFailed(message.isEmpty ? "adb exited with code \(result.exitCode)" : message)
        }

        return result
    }

    private func helpfulErrorMessage(for stderr: String, exitCode: Int32) -> String {
        let lowercasedStderr = stderr.lowercased()

        if lowercasedStderr.contains("device unauthorized") || lowercasedStderr.contains("unauthorized") {
            return "This phone is not authorized yet. Unlock it, approve the USB debugging RSA prompt, then refresh devices."
        }

        if lowercasedStderr.contains("device offline") || lowercasedStderr.contains("offline") {
            return "This phone is offline. Reconnect the USB cable, unlock the phone, then refresh devices."
        }

        if lowercasedStderr.contains("no devices") || lowercasedStderr.contains("device not found") {
            return "No Android device is available. Connect a phone by USB, enable USB debugging, then refresh devices."
        }

        if lowercasedStderr.contains("permission denied") {
            return "Android denied access to this path. Choose another folder or allow file access on the phone."
        }

        if lowercasedStderr.contains("no such file") {
            return "That Android file or folder no longer exists. Refresh the folder and try again."
        }

        return stderr.isEmpty ? "adb exited with code \(exitCode)" : stderr
    }
}
