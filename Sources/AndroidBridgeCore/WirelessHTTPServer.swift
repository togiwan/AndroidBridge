import Darwin
import Foundation
import Network

public final class WirelessHTTPServer: @unchecked Sendable {
    public typealias UploadHandler = @Sendable (_ filename: String, _ data: Data) -> Void

    public struct Configuration: Sendable {
        public let port: UInt16
        public let maximumRequestBytes: Int

        public init(port: UInt16 = 8123, maximumRequestBytes: Int = 512 * 1_024 * 1_024) {
            self.port = port
            self.maximumRequestBytes = maximumRequestBytes
        }
    }

    private let configuration: Configuration
    private let queue = DispatchQueue(label: "AndroidBridge.WirelessHTTPServer")
    private let uploadHandlerLock = NSLock()
    private var listener: NWListener?
    private var session: WirelessTransferSession?
    private var uploadHandler: UploadHandler?

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

    public func setUploadHandler(_ handler: UploadHandler?) {
        uploadHandlerLock.lock()
        uploadHandler = handler
        uploadHandlerLock.unlock()
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequestData(connection, buffer: Data())
    }

    private func receiveRequestData(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1_024) { [weak self] data, _, isComplete, _ in
            guard let self else {
                connection.cancel()
                return
            }

            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if nextBuffer.count > self.configuration.maximumRequestBytes {
                self.send(self.httpResponse(status: "413 Payload Too Large", body: "Upload is too large"), on: connection)
                return
            }

            if let response = self.responseIfComplete(for: nextBuffer, isComplete: isComplete) {
                self.send(response, on: connection)
                return
            }

            self.receiveRequestData(connection, buffer: nextBuffer)
        }
    }

    private func send(_ response: Data, on connection: NWConnection) {
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func responseIfComplete(for requestData: Data, isComplete: Bool) -> Data? {
        guard let requestLength = expectedRequestLength(for: requestData) else {
            return isComplete ? httpResponse(status: "400 Bad Request", body: "Invalid request") : nil
        }

        guard requestData.count >= requestLength else {
            return isComplete ? httpResponse(status: "400 Bad Request", body: "Incomplete request") : nil
        }

        return response(for: requestData.prefix(requestLength))
    }

    private func response(for requestData: Data.SubSequence) -> Data {
        guard let session else {
            return httpResponse(status: "503 Service Unavailable", body: "No active session")
        }

        guard let separatorRange = requestData.range(of: Data("\r\n\r\n".utf8)),
              let header = String(data: requestData[..<separatorRange.lowerBound], encoding: .utf8) else {
            return httpResponse(status: "400 Bad Request", body: "Invalid request")
        }

        let body = Data(requestData[separatorRange.upperBound...])
        let firstLine = header.components(separatedBy: "\r\n").first ?? ""
        let parts = firstLine.split(separator: " ")
        let method = parts.first.map(String.init) ?? "GET"
        let path = parts.count >= 2 ? String(parts[1]) : "/"

        guard path.contains(session.token.urlToken) || path == "/" || path == "/pin" || path == "/upload" || path.hasPrefix("/download/") else {
            return httpResponse(status: "404 Not Found", body: "Session not found")
        }

        if method == "POST", path == "/pin" {
            return handlePIN(body: body, session: session)
        }

        let authenticated = isAuthenticated(header: header, session: session)

        if method == "POST", path == "/upload" {
            guard authenticated else {
                return httpResponse(status: "403 Forbidden", body: "Enter the PIN before uploading files.")
            }
            return handleUpload(header: header, body: body)
        }

        if path.hasPrefix("/download/") {
            guard authenticated else {
                return httpResponse(status: "403 Forbidden", body: "Enter the PIN before downloading files.")
            }
            return handleDownload(path: path, session: session)
        }

        let html = WirelessHTMLRenderer.pageHTML(sharedItems: session.sharedItems, authenticated: authenticated)
        return httpResponse(status: "200 OK", body: html, contentType: "text/html; charset=utf-8")
    }

    private func handlePIN(body: Data, session: WirelessTransferSession) -> Data {
        guard postedPIN(from: body) == session.token.pin else {
            let html = WirelessHTMLRenderer.pageHTML(sharedItems: session.sharedItems, authenticated: false)
            return httpResponse(status: "403 Forbidden", body: html, contentType: "text/html; charset=utf-8")
        }

        return httpRedirect(
            location: "/\(session.token.urlToken)",
            headers: ["Set-Cookie: AndroidBridgePIN=\(session.token.urlToken); Path=/; SameSite=Strict"]
        )
    }

    private func isAuthenticated(header: String, session: WirelessTransferSession) -> Bool {
        header.contains("Cookie: AndroidBridgePIN=\(session.token.urlToken)")
    }

    private func postedPIN(from body: Data) -> String? {
        guard let bodyString = String(data: body, encoding: .utf8) else {
            return nil
        }

        return bodyString
            .components(separatedBy: "&")
            .first { $0.hasPrefix("pin=") }?
            .replacingOccurrences(of: "pin=", with: "")
            .removingPercentEncoding
    }

    private func handleDownload(path: String, session: WirelessTransferSession) -> Data {
        let idString = path.replacingOccurrences(of: "/download/", with: "")
        guard let id = UUID(uuidString: idString),
              let item = session.sharedItem(id: id) else {
            return httpResponse(status: "404 Not Found", body: "Shared item not found")
        }

        switch item.kind {
        case .file:
            return fileResponse(url: item.url, downloadName: item.downloadName)
        case .folder:
            return httpResponse(status: "409 Conflict", body: "Folder ZIP is being prepared. Refresh and try again.")
        }
    }

    private func fileResponse(url: URL, downloadName: String) -> Data {
        guard let data = try? Data(contentsOf: url) else {
            return httpResponse(status: "404 Not Found", body: "File not found")
        }

        let safeName = downloadName.replacingOccurrences(of: "\"", with: "")
        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: application/octet-stream\r
        Content-Disposition: attachment; filename="\(safeName)"\r
        Content-Length: \(data.count)\r
        Connection: close\r
        \r

        """
        return Data(header.utf8) + data
    }

    private func handleUpload(header: String, body: Data) -> Data {
        guard let boundary = multipartBoundary(from: header) else {
            return httpResponse(status: "400 Bad Request", body: "Invalid upload")
        }

        let parts = multipartParts(body: body, boundary: boundary)
        var savedCount = 0

        for part in parts {
            guard let filename = filename(from: part.headers) else {
                continue
            }
            currentUploadHandler()?(filename, part.body)
            savedCount += 1
        }

        return httpResponse(status: "200 OK", body: "Uploaded \(savedCount) file(s).")
    }

    private func currentUploadHandler() -> UploadHandler? {
        uploadHandlerLock.lock()
        defer { uploadHandlerLock.unlock() }
        return uploadHandler
    }

    private func expectedRequestLength(for data: Data) -> Int? {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }

        let headerLength = headerEnd.upperBound
        guard let header = String(data: data[..<headerEnd.lowerBound], encoding: .utf8) else {
            return nil
        }

        guard let contentLength = contentLength(from: header) else {
            return headerLength
        }

        return headerLength + contentLength
    }

    private func contentLength(from header: String) -> Int? {
        header
            .components(separatedBy: "\r\n")
            .first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":", maxSplits: 1).last?.trimmingCharacters(in: .whitespaces) ?? "") }
    }

    private func multipartBoundary(from header: String) -> String? {
        header
            .components(separatedBy: "\r\n")
            .first { $0.lowercased().hasPrefix("content-type: multipart/form-data;") }?
            .components(separatedBy: "boundary=")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func multipartParts(body: Data, boundary: String) -> [(headers: String, body: Data)] {
        let marker = Data("--\(boundary)".utf8)
        let lineBreak = Data("\r\n".utf8)
        let headerSeparator = Data("\r\n\r\n".utf8)
        var parts: [(headers: String, body: Data)] = []
        var searchStart = body.startIndex

        while let boundaryRange = body.range(of: marker, in: searchStart..<body.endIndex) {
            let partStart = boundaryRange.upperBound
            guard partStart < body.endIndex else {
                break
            }

            if body[partStart...].starts(with: Data("--".utf8)) {
                break
            }

            let contentStart = body[partStart...].starts(with: lineBreak) ? partStart + lineBreak.count : partStart
            guard let nextBoundary = body.range(of: marker, in: contentStart..<body.endIndex) else {
                break
            }

            var partData = Data(body[contentStart..<nextBoundary.lowerBound])
            if partData.suffix(lineBreak.count) == lineBreak {
                partData.removeLast(lineBreak.count)
            }

            if let separator = partData.range(of: headerSeparator),
               let headers = String(data: partData[..<separator.lowerBound], encoding: .utf8) {
                parts.append((headers: headers, body: Data(partData[separator.upperBound...])))
            }

            searchStart = nextBoundary.lowerBound
        }

        return parts
    }

    private func filename(from headers: String) -> String? {
        guard let disposition = headers
            .components(separatedBy: "\r\n")
            .first(where: { $0.lowercased().contains("content-disposition:") }),
              let range = disposition.range(of: "filename=\"") else {
            return nil
        }

        let suffix = disposition[range.upperBound...]
        guard let end = suffix.firstIndex(of: "\"") else {
            return nil
        }
        return String(suffix[..<end])
    }

    private func httpRedirect(location: String, headers: [String] = []) -> Data {
        let extraHeaders = headers.map { "\($0)\r\n" }.joined()
        let header = """
        HTTP/1.1 303 See Other\r
        Location: \(location)\r
        \(extraHeaders)Content-Length: 0\r
        Connection: close\r
        \r

        """
        return Data(header.utf8)
    }

    private func httpResponse(
        status: String,
        body: String,
        contentType: String = "text/plain; charset=utf-8",
        headers: [String] = []
    ) -> Data {
        let bodyData = Data(body.utf8)
        let extraHeaders = headers.map { "\($0)\r\n" }.joined()
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        \(extraHeaders)Connection: close\r
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
