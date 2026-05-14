public enum AndroidSelectionSummary {
    public static func downloadTitle(for items: [AndroidFileItem]) -> String {
        if items.count == 1, let item = items.first {
            return item.name
        }

        return "\(items.count) items"
    }

    public static func progressTitle(for item: AndroidFileItem, index: Int, totalCount: Int) -> String {
        guard totalCount > 1 else {
            return item.name
        }

        return "\(index + 1)/\(totalCount) \(item.name)"
    }

    public static func completedMessage(for items: [AndroidFileItem], directoryName: String) -> String {
        "Downloaded \(downloadTitle(for: items)) to \(directoryName)."
    }
}
