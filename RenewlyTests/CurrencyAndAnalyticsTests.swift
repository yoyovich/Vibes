import XCTest
@testable import Renewly

final class CurrencyConverterTests: XCTestCase {
    func testBaseCurrencyAlwaysHasRateOne() {
        let converter = CurrencyConverter(baseCode: "EUR", rates: [:])
        XCTAssertEqual(converter.convert(10, from: "EUR"), 10)
        XCTAssertFalse(converter.isRateMissing(for: "EUR"))
    }

    func testMissingRateFallsBackToOneAndIsFlagged() {
        let converter = CurrencyConverter(baseCode: "EUR", rates: [:])
        XCTAssertEqual(converter.convert(dec("12.5"), from: "USD"), dec("12.5"))
        XCTAssertTrue(converter.isRateMissing(for: "USD"))
    }

    func testZeroAndNegativeRatesAreTreatedAsMissing() {
        let converter = CurrencyConverter(baseCode: "EUR", rates: ["USD": 0, "GBP": -2])
        XCTAssertTrue(converter.isRateMissing(for: "USD"))
        XCTAssertTrue(converter.isRateMissing(for: "GBP"))
        XCTAssertEqual(converter.convert(5, from: "GBP"), 5)
    }

    func testConversionMultipliesByRate() {
        let converter = CurrencyConverter(baseCode: "RUB", rates: ["USD": dec("90.5")])
        XCTAssertEqual(converter.convert(2, from: "USD"), 181)
    }

    func testRebasingRecalculatesRates() {
        let converter = CurrencyConverter(baseCode: "RUB", rates: ["USD": 100, "EUR": 110])
        let rebased = converter.rebased(to: "USD")
        XCTAssertEqual(rebased["EUR"], dec("1.1"))
        XCTAssertEqual(rebased["RUB"], dec("0.01"))
        XCTAssertNil(rebased["USD"])
    }

    func testRebasingWithoutPivotRateClearsRates() {
        let converter = CurrencyConverter(baseCode: "RUB", rates: ["USD": 100])
        XCTAssertTrue(converter.rebased(to: "JPY").isEmpty)
    }
}

final class SpendingAnalyticsTests: XCTestCase {
    private typealias D = TestCalendar
    private let analytics = SpendingAnalytics(
        schedule: TestCalendar.schedule,
        converter: CurrencyConverter(baseCode: "USD", rates: ["EUR": 2])
    )

    func testMonthlyTotalExcludesPausedAndEndedSubscriptions() {
        let now = D.date(2025, 6, 10)
        let items = [
            makeSubscription(amount: "10", anchor: D.date(2025, 1, 1)),
            makeSubscription(amount: "5", currency: "EUR", anchor: D.date(2025, 1, 1)),
            makeSubscription(amount: "100", anchor: D.date(2025, 1, 1), status: .paused, pausedAt: D.date(2025, 5, 1)),
            makeSubscription(amount: "7", anchor: D.date(2025, 1, 1), status: .cancelled, cancellation: D.date(2025, 6, 1)),
            makeSubscription(amount: "3", anchor: D.date(2025, 1, 1), status: .cancelled, cancellation: D.date(2025, 7, 1))
        ]
        XCTAssertEqual(analytics.monthlyTotal(items, now: now), 23)
        XCTAssertEqual(analytics.yearlyTotal(items, now: now), 276)
    }

    func testForecastUsesRealChargeDatesNotMonthlyAverage() {
        let now = D.date(2025, 1, 1)
        let weekly = makeSubscription(amount: "10", period: .weekly, anchor: D.date(2025, 1, 1))
        let entries = analytics.forecast([weekly], now: now, months: 3)
        // January 2025 has five Wednesdays, February four, March four.
        XCTAssertEqual(entries.map(\.amount), [50, 40, 40])
        XCTAssertNotEqual(entries.first?.amount, BillingSchedule.monthlyCost(of: weekly))
    }

    func testForecastHandlesMonthEndTrialPauseAndCancellation() {
        let now = D.date(2024, 2, 1)
        let items = [
            makeSubscription(amount: "10", anchor: D.date(2024, 1, 31), category: .streaming),
            makeSubscription(amount: "20", anchor: D.date(2024, 1, 1), category: .music, trialEnd: D.date(2024, 3, 15)),
            makeSubscription(amount: "40", anchor: D.date(2024, 1, 1), category: .cloud, status: .paused, pausedAt: D.date(2024, 1, 20)),
            makeSubscription(amount: "5", currency: "EUR", anchor: D.date(2024, 1, 3), category: .news, status: .cancelled, cancellation: D.date(2024, 3, 10))
        ]
        let entries = analytics.forecast(items, now: now, months: 3)
        func amount(_ month: Int, _ category: SubscriptionCategory) -> Decimal? {
            entries.first { $0.month == D.date(2024, month, 1) && $0.category == category }?.amount
        }
        XCTAssertEqual(amount(2, .streaming), 10)
        XCTAssertNil(amount(2, .music))
        XCTAssertEqual(amount(3, .music), 20)
        XCTAssertNil(entries.first { $0.category == .cloud })
        XCTAssertEqual(amount(2, .news), 10)
        XCTAssertEqual(amount(3, .news), 10)
        XCTAssertNil(amount(4, .news))
    }

    func testUpcomingListsChargesWithinThirtyDaysSorted() {
        let now = D.date(2025, 1, 20, hour: 12)
        let items = [
            makeSubscription(name: "B", anchor: D.date(2024, 12, 25)),
            makeSubscription(name: "A", anchor: D.date(2024, 11, 20))
        ]
        let upcoming = analytics.upcoming(items, now: now)
        // A: Jan 20 (today) and Feb 20 (31 days, outside the window); B: Jan 25.
        XCTAssertEqual(upcoming.map(\.name), ["A", "B"])
        XCTAssertEqual(upcoming.map(\.daysLeft), [0, 5])
        XCTAssertEqual(analytics.upcoming(items, now: now, days: 31).map(\.name), ["A", "B", "A"])
    }

    func testTopFiveSortsByMonthlyCostInBaseCurrency() {
        let now = D.date(2025, 1, 1)
        let items = (1...7).map { makeSubscription(name: "S\($0)", amount: "\($0)", anchor: D.date(2024, 1, 1)) }
            + [makeSubscription(name: "Euro", amount: "4", currency: "EUR", anchor: D.date(2024, 1, 1))]
        let top = analytics.mostExpensive(items, now: now)
        XCTAssertEqual(top.map(\.subscription.name), ["Euro", "S7", "S6", "S5", "S4"])
    }

    func testMissingRateIsReported() {
        let items = [makeSubscription(currency: "JPY", anchor: D.date(2025, 1, 1))]
        XCTAssertTrue(analytics.hasMissingRates(items, now: D.date(2025, 2, 1)))
    }
}
