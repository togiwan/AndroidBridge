import Foundation

public struct WirelessTransferToken: Equatable, Sendable {
    public let urlToken: String
    public let pin: String

    public init(urlToken: String, pin: String) {
        self.urlToken = urlToken
        self.pin = pin
    }

    public static func generate() -> WirelessTransferToken {
        let tokenBytes = (0..<24).map { _ in UInt8.random(in: 0...255) }
        let urlToken = tokenBytes.map { String(format: "%02x", $0) }.joined()
        let pin = String(format: "%06d", Int.random(in: 0...999_999))
        return WirelessTransferToken(urlToken: urlToken, pin: pin)
    }

    public static func isValidPIN(_ value: String) -> Bool {
        value.count == 6 && value.allSatisfy(\.isNumber)
    }
}
