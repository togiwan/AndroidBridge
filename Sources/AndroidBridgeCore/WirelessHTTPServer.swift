import Darwin
import Foundation
import Network

public final class WirelessHTTPServer: @unchecked Sendable {
    public struct Configuration: Sendable {
        public let port: UInt16

        public init(port: UInt16 = 8123) {
            self.port = port
        }
    }

    private let configuration: Configuration
    private let queue = DispatchQueue(label: "AndroidBridge.WirelessHTTPServer")
    private var listener: NWListener?
    private var session: WirelessTransferSession?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func start(session: WirelessTransferSession) throws -> URL {
        self.session = session
        let parameters = NWParameters.tcp
        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: configuration.port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)

        return URL(string: "http://\(Self.bestLocalAddress()):\(configuration.port)/\(session.token.urlToken)")!
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        session = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { [weak self] data, _, _, _ in
            guard let self, let data, let request = String(data: data, encoding: .utf8) else {
                connection.cancel()
                return
            }
            let response = self.response(for: request)
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func response(for request: String) -> Data {
        guard let session else {
            return httpResponse(status: "503 Service Unavailable", body: "No active session")
        }

        let firstLine = request.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let path = parts.count >= 2 ? String(parts[1]) : "/"

        guard path.contains(session.token.urlToken) || path == "/" else {
            return httpResponse(status: "404 Not Found", body: "Session not found")
        }

        let html = WirelessHTMLRenderer.pageHTML(sharedItems: session.sharedItems, authenticated: true)
        return httpResponse(status: "200 OK", body: html, contentType: "text/html; charset=utf-8")
    }

    private func httpResponse(status: String, body: String, contentType: String = "text/plain; charset=utf-8") -> Data {
        let bodyData = Data(body.utf8)
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        return Data(header.utf8) + bodyData
    }

    private static func bestLocalAddress() -> String {
        var address = "127.0.0.1"
        var ifaddrPointer: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddrPointer) == 0, let firstAddress = ifaddrPointer else {
            return address
        }
        defer { freeifaddrs(ifaddrPointer) }

        for pointer in sequence(first: firstAddress, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard let socketAddress = interface.ifa_addr else {
                continue
            }

            let family = socketAddress.pointee.sa_family
            guard family == UInt8(AF_INET) else {
                continue
            }

            let name = String(cString: interface.ifa_name)
            guard name == "en0" || name == "en1" else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                socketAddress,
                socklen_t(socketAddress.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )
            address = String(cString: hostname)
            break
        }

        return address
    }
}
