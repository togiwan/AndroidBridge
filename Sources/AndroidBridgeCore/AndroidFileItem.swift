import Foundation

public struct AndroidFileItem: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let kind: AndroidFileKind
    public let size: Int64

    public init(name: String, path: String, kind: AndroidFileKind, size: Int64) {
        self.id = path
        self.name = name
        self.path = path
        self.kind = kind
        self.size = size
    }
}

public enum AndroidFileKind: Equatable, Hashable, Sendable {
    case file
    case folder
}
