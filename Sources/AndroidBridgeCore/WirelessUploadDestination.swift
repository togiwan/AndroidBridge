import Foundation

public enum WirelessUploadDestination {
    public static func destination(
        originalFilename: String,
        receiveFolder: URL,
        existingFilenames: Set<String>
    ) -> URL {
        let sanitized = sanitizedFilename(originalFilename)
        var candidate = sanitized
        var index = 2

        let nsName = sanitized as NSString
        let base = nsName.deletingPathExtension
        let ext = nsName.pathExtension

        while existingFilenames.contains(candidate) {
            candidate = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            index += 1
        }

        return receiveFolder.appendingPathComponent(candidate)
    }

    public static func sanitizedFilename(_ filename: String) -> String {
        let trimmed = filename.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "upload" : trimmed
        return fallback
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }
}
