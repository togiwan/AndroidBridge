import Foundation

public struct AndroidDevice: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let state: AndroidDeviceState

    public init(id: String, state: AndroidDeviceState) {
        self.id = id
        self.state = state
    }

    public var displayState: String {
        switch state {
        case .device:
            "Connected"
        case .unauthorized:
            "Unauthorized"
        case .offline:
            "Offline"
        case .unknown:
            "Unknown"
        }
    }
}

public enum AndroidDeviceState: String, Equatable, Hashable, Sendable {
    case device
    case unauthorized
    case offline
    case unknown
}
