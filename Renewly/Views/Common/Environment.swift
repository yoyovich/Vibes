import SwiftUI

private struct CurrencyConverterKey: EnvironmentKey {
    static let defaultValue = CurrencyConverter(baseCode: CurrencyCatalog.defaultBase, rates: [:])
}

extension EnvironmentValues {
    /// Converter built from the base currency setting and the stored rates; shared by every screen.
    var currencyConverter: CurrencyConverter {
        get { self[CurrencyConverterKey.self] }
        set { self[CurrencyConverterKey.self] = newValue }
    }
}

extension Decimal {
    func currencyText(_ code: String) -> String {
        formatted(.currency(code: code))
    }
}

extension Date {
    var dayText: String { formatted(date: .abbreviated, time: .omitted) }
}

/// Unified access to the pure logic with the user's calendar and current rates.
struct LogicContext {
    let converter: CurrencyConverter
    let calendar: Calendar

    init(converter: CurrencyConverter, calendar: Calendar = .current) {
        self.converter = converter
        self.calendar = calendar
    }

    var schedule: BillingSchedule { BillingSchedule(calendar: calendar) }
    var analytics: SpendingAnalytics { SpendingAnalytics(schedule: schedule, converter: converter) }
}
