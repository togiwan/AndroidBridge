import Foundation

public struct ADBWirelessClient: Sendable {
    private let command: ADBCommand
    private let runner: ProcessRunning

    public init(command: ADBCommand = ADBExecutableResolver.resolve(), runner: ProcessRunning = FoundationProcessRunner()) {
        self.command = command
        self.runner = runner
    }

    public func pair(address: String, code: String) async throws {
        _ = try await run(arguments: ["pair", address, code])
    }

    public func connect(address: String) async throws {
        _ = try await run(arguments: ["connect", address])
    }

    public func disconnect(address: String) async throws {
        _ = try await run(arguments: ["disconnect", address])
    }

    private func run(arguments: [String]) async throws -> ProcessResult {
        let result = try await runner.run(command.executable, arguments: command.leadingArguments + arguments)

        guard result.exitCode == 0 else {
            throw ADBClientError.commandFailed(helpfulErrorMessage(stderr: result.stderr, stdout: result.stdout, exitCode: result.exitCode))
        }

        return result
    }

    private func helpfulErrorMessage(stderr: String, stdout: String, exitCode: Int32) -> String {
        let combined = "\(stderr)\n\(stdout)".lowercased()

        if combined.contains("failed to authenticate") || combined.contains("wrong") {
            return "Pairing failed. Check the pairing code on your Android phone and try again."
        }

        if combined.contains("unable to connect") || combined.contains("connection refused") || combined.contains("timed out") {
            return "Could not connect to the phone. Make sure Mac and Android are on the same Wi-Fi and Wireless debugging is enabled."
        }

        let message = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "adb wireless command exited with code \(exitCode)" : message
    }
}
