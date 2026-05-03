import Foundation

public struct LocalPreviewPaths: Equatable, Sendable {
    public let directory: URL
    public let file: URL

    public init(directory: URL, file: URL) {
        self.directory = directory
        self.file = file
    }
}

public enum LocalPreviewDestination {
    public static func destination(
        for item: AndroidFileItem,
        temporaryDirectory: URL = FileManager.default.temporaryDirectory
    ) -> LocalPreviewPaths {
        let directory = temporaryDirectory.appendingPathComponent("AndroidBridgePreviews", isDirectory: true)
        return LocalPreviewPaths(
            directory: directory,
            file: directory.appendingPathComponent(item.name, isDirectory: false)
        )
    }
}
