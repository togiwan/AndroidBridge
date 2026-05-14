import Foundation

public struct ProcessResult: Sendable {
    public let stdout: String
    public let stderr: String
    public let exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public enum ProcessRunnerError: LocalizedError {
    case launchFailed(String)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            "Could not start command: \(message)"
        }
    }
}

public protocol ProcessRunning: Sendable {
    func run(_ executable: String, arguments: [String]) async throws -> ProcessResult
    func runStreaming(
        _ executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult
}

public final class FoundationProcessRunner: ProcessRunning, @unchecked Sendable {
    public init() {}

    public func run(_ executable: String, arguments: [String]) async throws -> ProcessResult {
        let execution = ProcessExecutionState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                switch execution.finish() {
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .completed:
                    continuation.resume(returning: ProcessResult(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    ))
                case .alreadyFinished:
                    return
                }
            }

            do {
                try process.run()
                if execution.attach(process) {
                    process.terminate()
                }
            } catch {
                if execution.finish() != .alreadyFinished {
                    continuation.resume(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                }
            }
            }
        } onCancel: {
            execution.cancel()
        }
    }

    public func runStreaming(
        _ executable: String,
        arguments: [String],
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> ProcessResult {
        let execution = ProcessExecutionState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let stdoutBuffer = LockedDataBuffer()
            let stderrBuffer = LockedDataBuffer()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    return
                }

                stdoutBuffer.append(data)

                if let text = String(data: data, encoding: .utf8) {
                    onOutput(text)
                }
            }

            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    return
                }

                stderrBuffer.append(data)

                if let text = String(data: data, encoding: .utf8) {
                    onOutput(text)
                }
            }

            process.terminationHandler = { process in
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                let stdout = stdoutBuffer.stringValue()
                let stderr = stderrBuffer.stringValue()

                switch execution.finish() {
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .completed:
                    continuation.resume(returning: ProcessResult(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    ))
                case .alreadyFinished:
                    return
                }
            }

            do {
                try process.run()
                if execution.attach(process) {
                    process.terminate()
                }
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                if execution.finish() != .alreadyFinished {
                    continuation.resume(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                }
            }
            }
        } onCancel: {
            execution.cancel()
        }
    }
}

private final class ProcessExecutionState: @unchecked Sendable {
    enum FinishState {
        case completed
        case cancelled
        case alreadyFinished
    }

    private let lock = NSLock()
    private var process: Process?
    private var isCancelled = false
    private var isFinished = false

    func attach(_ process: Process) -> Bool {
        lock.lock()
        self.process = process
        let shouldTerminate = isCancelled
        lock.unlock()
        return shouldTerminate
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let process = process
        lock.unlock()

        process?.terminate()
    }

    func finish() -> FinishState {
        lock.lock()
        defer { lock.unlock() }

        guard !isFinished else {
            return .alreadyFinished
        }

        isFinished = true
        return isCancelled ? .cancelled : .completed
    }
}

private final class LockedDataBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    func stringValue() -> String {
        lock.lock()
        let currentData = data
        lock.unlock()

        return String(data: currentData, encoding: .utf8) ?? ""
    }
}
