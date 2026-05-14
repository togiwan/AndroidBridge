import Foundation

public enum LocalUploadSelectionSummary {
    public static func uploadTitle(for urls: [URL]) -> String {
        if urls.count == 1, let url = urls.first {
            return url.lastPathComponent
        }

        return "\(urls.count) items"
    }

    public static func progressTitle(for url: URL, index: Int, totalCount: Int) -> String {
        guard totalCount > 1 else {
            return url.lastPathComponent
        }

        return "\(index + 1)/\(totalCount) \(url.lastPathComponent)"
    }

    public static func completedMessage(for urls: [URL], remotePath: String) -> String {
        "Uploaded \(uploadTitle(for: urls)) to \(remotePath)."
    }
}
