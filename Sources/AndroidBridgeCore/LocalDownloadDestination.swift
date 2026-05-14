import Foundation

public enum LocalDownloadDestination {
    public static func destination(
        for item: AndroidFileItem,
        downloadDirectory: URL
    ) -> (directory: URL, file: URL) {
        (
            directory: downloadDirectory,
            file: downloadDirectory.appendingPathComponent(item.name)
        )
    }
}
