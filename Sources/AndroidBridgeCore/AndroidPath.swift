import Foundation

public enum AndroidPath {
    public static func join(_ base: String, _ component: String) -> String {
        let cleanBase = base == "/" ? "" : base.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanComponent = component.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if cleanBase.isEmpty {
            return "/" + cleanComponent
        }

        return "/" + cleanBase + "/" + cleanComponent
    }

    public static func parent(of path: String) -> String {
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !cleanPath.isEmpty else {
            return "/"
        }

        var components = cleanPath.split(separator: "/").map(String.init)
        guard components.count > 1 else {
            return "/"
        }

        components.removeLast()
        return "/" + components.joined(separator: "/")
    }

    public static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
