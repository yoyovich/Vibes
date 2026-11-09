import Foundation

/// Twelve realistic sample subscriptions with fixed identifiers, so loading twice never duplicates.
enum DemoData {
    /// Approximate value of one unit in US dollars, only used to prefill rates for the demo.
    static let approximateUSDValue: [String: Decimal] = [
        "USD": "1", "EUR": "1.08", "GBP": "1.27", "RUB": "0.011", "JPY": "0.0066", "CNY": "0.14",
        "CHF": "1.13", "CAD": "0.73", "AUD": "0.66", "KZT": "0.002", "UAH": "0.024", "TRY": "0.029",
        "INR": "0.012", "BRL": "0.18", "PLN": "0.25", "SEK": "0.095", "AED": "0.27", "KRW": "0.00073"
    ].compactMapValues(AmountParser.parse)

    /// Demo rates for currencies that have no user-entered rate yet.
    static func suggestedRates(base: String, existing: [String: Decimal], codes: Set<String>) -> [String: Decimal] {
        guard let baseValue = approximateUSDValue[base], baseValue > 0 else { return [:] }
        var result: [String: Decimal] = [:]
        for code in codes where code != base && existing[code] == nil {
            if let value = approximateUSDValue[code] {
                result[code] = (value / baseValue).rounded(scale: 6)
            }
        }
        return result
    }

    private static func money(_ text: String) -> Decimal {
        AmountParser.parse(text) ?? 1
    }

    static func subscriptions(now: Date, calendar: Calendar = .current) -> [SubscriptionSnapshot] {
        let today = calendar.startOfDay(for: now)
        let year = calendar.component(.year, from: today)
        func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? today
        }
        func offset(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: days, to: today) ?? today
        }
        func id(_ suffix: Int) -> UUID {
            UUID(uuidString: String(format: "D3E0D3E0-0000-4000-8000-%012ld", suffix)) ?? UUID()
        }

        return [
            SubscriptionSnapshot(id: id(1), name: "Netflix", amount: money("15.49"), currencyCode: "USD", period: .monthly,
                                 anchorDate: date(year - 1, 1, 31), category: .streaming, note: String(localized: "Standard plan, charged on the 31st"),
                                 reminder: .oneDay),
            SubscriptionSnapshot(id: id(2), name: "Spotify Premium", amount: money("10.99"), currencyCode: "EUR", period: .monthly,
                                 anchorDate: date(year - 2, 5, 14), category: .music, reminder: .sameDay),
            SubscriptionSnapshot(id: id(3), name: "iCloud+ 200 GB", amount: money("2.99"), currencyCode: "USD", period: .monthly,
                                 anchorDate: date(year - 3, 8, 3), category: .cloud, reminder: .off),
            SubscriptionSnapshot(id: id(4), name: "Adobe Creative Cloud", amount: money("263.88"), currencyCode: "USD", period: .yearly,
                                 anchorDate: date(2024, 2, 29), category: .software, note: String(localized: "Renews on February 29 in leap years"),
                                 reminder: .oneWeek),
            SubscriptionSnapshot(id: id(5), name: "FitLife Gym", amount: money("3500"), currencyCode: "RUB", period: .monthly,
                                 anchorDate: date(year - 1, 3, 31), category: .fitness, reminder: .threeDays),
            SubscriptionSnapshot(id: id(6), name: "Nintendo Switch Online", amount: money("2400"), currencyCode: "JPY", period: .yearly,
                                 anchorDate: date(year - 1, 11, 20), category: .gaming, reminder: .oneWeek),
            SubscriptionSnapshot(id: id(7), name: "ChatGPT Plus", amount: money("20"), currencyCode: "USD", period: .monthly,
                                 anchorDate: offset(-75), category: .software, reminder: .oneDay),
            SubscriptionSnapshot(id: id(8), name: "The Economist", amount: money("59"), currencyCode: "GBP", period: .quarterly,
                                 anchorDate: date(year - 1, 8, 31), category: .news, reminder: .threeDays),
            SubscriptionSnapshot(id: id(9), name: "Duolingo Super", amount: money("83.99"), currencyCode: "USD", period: .yearly,
                                 anchorDate: offset(-4), category: .education, note: String(localized: "Free trial, first charge when it ends"),
                                 trialEndDate: offset(10), reminder: .oneDay),
            SubscriptionSnapshot(id: id(10), name: "Disney+", amount: money("8.99"), currencyCode: "EUR", period: .monthly,
                                 anchorDate: date(year - 1, 6, 12), category: .streaming, reminder: .oneDay,
                                 status: .paused, pausedAt: offset(-20)),
            SubscriptionSnapshot(id: id(11), name: "Dropbox Plus", amount: money("11.99"), currencyCode: "USD", period: .monthly,
                                 anchorDate: date(year - 2, 10, 5), category: .cloud, note: String(localized: "Cancelled, active until the end of the period"),
                                 reminder: .oneDay, status: .cancelled, cancellationDate: offset(20)),
            SubscriptionSnapshot(id: id(12), name: "Bean Box Coffee", amount: money("18"), currencyCode: "CHF",
                                 period: BillingPeriod(unit: .week, count: 2), anchorDate: offset(-30), category: .other,
                                 reminder: .off)
        ]
    }
}
