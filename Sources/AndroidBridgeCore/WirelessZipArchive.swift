import Foundation

public enum WirelessZipArchiveError: LocalizedError {
    case archiveFailed(String)

    public var errorDescription: String? {
        switch self {
        case .archiveFailed(let message):
            message
        }
    }
}

public enum WirelessZipArchive {
    public static func archiveFilename(for item: SharedDownloadItem) -> String {
        item.downloadName
    }

    public static func createArchive(
        for item: SharedDownloadItem,
        runner: ProcessRunning = FoundationProcessRunner()
    ) async throws -> URL {
        let archiveURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AndroidBridgeWireless")
            .appendingPathComponent(item.id.uuidString)
            .appendingPathComponent(archiveFilename(for: item))

        try FileManager.default.createDirectory(
            at: archiveURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let result = try await runner.run("/usr/bin/ditto", arguments: [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            item.url.path,
            archiveURL.path
        ])

        guard result.exitCode == 0 else {
            let message = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw WirelessZipArchiveError.archiveFailed(message.isEmpty ? "Could not create ZIP archive." : message)
        }

        return archiveURL
    }
}
