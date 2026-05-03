import Foundation

public struct TransferProgressEstimate: Equatable, Sendable {
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    public let elapsedSeconds: TimeInterval

    public init(bytesTransferred: Int64, totalBytes: Int64, elapsedSeconds: TimeInterval) {
        self.bytesTransferred = max(0, bytesTransferred)
        self.totalBytes = max(0, totalBytes)
        self.elapsedSeconds = max(0, elapsedSeconds)
    }

    public var fraction: Double {
        guard totalBytes > 0 else {
            return 0
        }

        return min(max(Double(bytesTransferred) / Double(totalBytes), 0), 1)
    }

    public var percent: Int {
        Int((fraction * 100).rounded(.down))
    }

    public var remainingSeconds: Int? {
        guard bytesTransferred > 0, totalBytes > 0, fraction < 1 else {
            return nil
        }

        let bytesPerSecond = Double(bytesTransferred) / max(elapsedSeconds, 0.1)
        guard bytesPerSecond > 0 else {
            return nil
        }

        let remainingBytes = Double(totalBytes - bytesTransferred)
        return max(0, Int((remainingBytes / bytesPerSecond).rounded()))
    }
}
