import Foundation

public final class WirelessTransferSession: @unchecked Sendable {
    public let token: WirelessTransferToken
    public let authCookieValue: String
    public let receiveFolder: URL

    private let lock = NSLock()
    private var items: [SharedDownloadItem] = []

    public init(
        token: WirelessTransferToken = .generate(),
        authCookieValue: String = WirelessTransferToken.generate().urlToken,
        receiveFolder: URL
    ) {
        self.token = token
        self.authCookieValue = authCookieValue
        self.receiveFolder = receiveFolder
    }

    public var sharedItems: [SharedDownloadItem] {
        lock.lock()
        defer { lock.unlock() }
        return items
    }

    public func addSharedItems(_ newItems: [SharedDownloadItem]) {
        lock.lock()
        items.append(contentsOf: newItems)
        lock.unlock()
    }

    public func removeSharedItem(id: SharedDownloadItem.ID) {
        lock.lock()
        items.removeAll { $0.id == id }
        lock.unlock()
    }

    public func clearSharedItems() {
        lock.lock()
        items.removeAll()
        lock.unlock()
    }

    public func sharedItem(id: SharedDownloadItem.ID) -> SharedDownloadItem? {
        lock.lock()
        defer { lock.unlock() }
        return items.first { $0.id == id }
    }
}
