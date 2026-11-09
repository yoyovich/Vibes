import Foundation

/// Supported ISO 4217 currencies and their properties.
enum CurrencyCatalog {
    static let codes = [
        "USD", "EUR", "GBP", "RUB", "JPY", "CNY", "CHF", "CAD",
        "AUD", "KZT", "UAH", "TRY", "INR", "BRL", "PLN", "SEK",
        "AED", "KRW"
    ]

    static var defaultBase: String {
        if let code = Locale.current.currency?.identifier, codes.contains(code) {
            return code
        }
        return "USD"
    }

    static func displayName(for code: String, locale: Locale = .current) -> String {
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return "\(code) — \(name)"
    }

    /// Number of minor-unit digits, for example 2 for USD and 0 for JPY.
    static func fractionDigits(for code: String) -> Int {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.currencyCode = code
        return formatter.maximumFractionDigits
    }
}
