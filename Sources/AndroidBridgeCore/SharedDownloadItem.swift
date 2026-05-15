import Foundation

public struct SharedDownloadItem: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case file
        case folder
    }

    public let id: UUID
    public let url: URL
    public let kind: Kind
    public let byteCount: Int64?

    public init(id: UUID = UUID(), url: URL, kind: Kind, byteCount: Int64?) {
        self.id = id
        self.url = url
        self.kind = kind
        self.byteCount = byteCount
    }

    public var name: String {
        url.lastPathComponent
    }

    public var downloadName: String {
        switch kind {
        case .file:
            name
        case .folder:
            "\(name).zip"
        }
    }
}
