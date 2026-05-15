import Foundation

public struct ADBWirelessService: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        case pairing
        case connect
    }

    public let id: String
    public let name: String
    public let host: String
    public let port: UInt16
    public let kind: Kind

    public init(name: String, host: String, port: UInt16, kind: Kind) {
        self.id = "\(host):\(port):\(kind.rawValue)"
        self.name = name
        self.host = host
        self.port = port
        self.kind = kind
    }

    public var address: String {
        "\(host):\(port)"
    }
}

public final class ADBWirelessDiscovery: NSObject, @unchecked Sendable {
    public typealias UpdateHandler = @Sendable ([ADBWirelessService]) -> Void

    private let pairingBrowser = NetServiceBrowser()
    private let connectBrowser = NetServiceBrowser()
    private let lock = NSLock()
    private var servicesByID: [String: ADBWirelessService] = [:]
    private var resolvingServices: [NetService] = []
    private var onUpdate: UpdateHandler?

    public override init() {
        super.init()
        pairingBrowser.delegate = self
        connectBrowser.delegate = self
    }

    public func start(onUpdate: @escaping UpdateHandler) {
        lock.lock()
        servicesByID = [:]
        resolvingServices = []
        self.onUpdate = onUpdate
        lock.unlock()

        pairingBrowser.searchForServices(ofType: "_adb-tls-pairing._tcp.", inDomain: "local.")
        connectBrowser.searchForServices(ofType: "_adb-tls-connect._tcp.", inDomain: "local.")
    }

    public func stop() {
        pairingBrowser.stop()
        connectBrowser.stop()

        lock.lock()
        resolvingServices.forEach { $0.stop() }
        resolvingServices = []
        servicesByID = [:]
        lock.unlock()
    }

    private func addResolvedService(_ service: NetService, kind: ADBWirelessService.Kind) {
        guard let hostName = service.hostName, service.port > 0 else {
            return
        }

        let adbService = ADBWirelessService(
            name: service.name,
            host: hostName.trimmingCharacters(in: CharacterSet(charactersIn: ".")),
            port: UInt16(service.port),
            kind: kind
        )

        lock.lock()
        servicesByID[adbService.id] = adbService
        let services = servicesByID.values.sorted { $0.name < $1.name }
        lock.unlock()

        onUpdate?(services)
    }

    private func kind(for service: NetService) -> ADBWirelessService.Kind? {
        if service.type == "_adb-tls-pairing._tcp." {
            return .pairing
        }

        if service.type == "_adb-tls-connect._tcp." {
            return .connect
        }

        return nil
    }
}

extension ADBWirelessDiscovery: NetServiceBrowserDelegate {
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self

        lock.lock()
        resolvingServices.append(service)
        lock.unlock()

        service.resolve(withTimeout: 5)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        guard let kind = kind(for: service) else {
            return
        }

        lock.lock()
        servicesByID = servicesByID.filter { _, value in
            !(value.name == service.name && value.kind == kind)
        }
        let services = servicesByID.values.sorted { $0.name < $1.name }
        lock.unlock()

        onUpdate?(services)
    }
}

extension ADBWirelessDiscovery: NetServiceDelegate {
    public func netServiceDidResolveAddress(_ sender: NetService) {
        guard let kind = kind(for: sender) else {
            return
        }

        addResolvedService(sender, kind: kind)
    }
}
