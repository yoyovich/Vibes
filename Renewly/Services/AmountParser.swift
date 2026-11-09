import Foundation

/// Parses user input for money amounts. Accepts both "," and "." as the decimal separator.
enum AmountParser {
    static let maximum = Decimal(string: "9999999.99", locale: Locale(identifier: "en_US_POSIX")) ?? 9_999_999

    static func parse(_ text: String) -> Decimal? {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCIIDigit) }),
              parts.contains(where: { !$0.isEmpty })
        else { return nil }
        return Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX"))
    }

    static func fractionDigitCount(_ text: String) -> Int {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let separator = normalized.lastIndex(of: ".") else { return 0 }
        return normalized[normalized.index(after: separator)...]
            .filter(\.isASCIIDigit)
            .count
    }

    /// Plain machine-readable representation, used for text fields and exports.
    static func plainString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).description(withLocale: Locale(identifier: "en_US_POSIX"))
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
