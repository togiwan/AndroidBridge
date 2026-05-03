import Foundation

public struct ADBTransferProgress: Equatable, Sendable {
    public let percent: Int

    public init(percent: Int) {
        self.percent = min(max(percent, 0), 100)
    }
}

public enum ADBTransferProgressParser {
    public static func parse(_ text: String) -> ADBTransferProgress? {
        guard let percentIndex = text.firstIndex(of: "%") else {
            return nil
        }

        var currentIndex = text.index(before: percentIndex)
        var digits = ""

        while true {
            let character = text[currentIndex]

            if character.isNumber {
                digits.insert(character, at: digits.startIndex)
            } else if !character.isWhitespace {
                break
            }

            if currentIndex == text.startIndex {
                break
            }

            currentIndex = text.index(before: currentIndex)
        }

        guard !digits.isEmpty, let percent = Int(digits) else {
            return nil
        }

        return ADBTransferProgress(percent: percent)
    }
}
