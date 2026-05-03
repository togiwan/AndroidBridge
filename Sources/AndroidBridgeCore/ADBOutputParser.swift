import Foundation

public enum ADBOutputParser {
    public static func parseDevices(_ output: String) -> [AndroidDevice] {
        output
            .split(whereSeparator: \.isNewline)
            .dropFirst()
            .compactMap { line in
                let parts = line.split(whereSeparator: \.isWhitespace)
                guard parts.count >= 2 else {
                    return nil
                }

                let state = AndroidDeviceState(rawValue: String(parts[1])) ?? .unknown
                return AndroidDevice(id: String(parts[0]), state: state)
            }
    }

    public static func parseFileListing(_ output: String, parentPath: String) -> [AndroidFileItem] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                parseFileListingLine(String(line), parentPath: parentPath)
            }
            .filter { $0.name != "." && $0.name != ".." }
            .sorted { left, right in
                if left.kind != right.kind {
                    return left.kind == .folder
                }

                return left.name.localizedStandardCompare(right.name) == .orderedAscending
            }
    }

    private static func parseFileListingLine(_ line: String, parentPath: String) -> AndroidFileItem? {
        guard !line.hasPrefix("total ") else {
            return nil
        }

        let parts = line.split(separator: " ", maxSplits: 7, omittingEmptySubsequences: true)
        guard parts.count == 8 else {
            return nil
        }

        let permissions = String(parts[0])
        let size = Int64(parts[4]) ?? 0
        let name = String(parts[7])
        let kind: AndroidFileKind = permissions.first == "d" ? .folder : .file

        return AndroidFileItem(
            name: name,
            path: AndroidPath.join(parentPath, name),
            kind: kind,
            size: size
        )
    }
}
