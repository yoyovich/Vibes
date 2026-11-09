import XCTest
@testable import Renewly

final class ReminderPlannerTests: XCTestCase {
    private typealias D = TestCalendar

    func testRemindersFireDaysBeforeAtChosenTime() {
        let item = makeSubscription(anchor: D.date(2025, 1, 31), reminder: .threeDays)
        let plans = ReminderPlanner.plan([item], now: D.date(2025, 2, 1), minutesAfterMidnight: 9 * 60 + 30, schedule: D.schedule)
        XCTAssertEqual(plans.first?.chargeDate, D.date(2025, 2, 28))
        XCTAssertEqual(plans.first?.fireDate, D.date(2025, 2, 25, hour: 9, minute: 30))
    }

    func testPastFireTimesAreSkipped() {
        let item = makeSubscription(anchor: D.date(2025, 1, 10), reminder: .sameDay)
        let plans = ReminderPlanner.plan([item], now: D.date(2025, 3, 10, hour: 10), minutesAfterMidnight: 9 * 60, schedule: D.schedule)
        XCTAssertEqual(plans.first?.chargeDate, D.date(2025, 4, 10))
    }

    func testLimitKeepsTheNearestSixtyFour() {
        let daily = makeSubscription(name: "Daily", period: BillingPeriod(unit: .day, count: 1), anchor: D.date(2025, 1, 1), reminder: .oneDay)
        let monthly = makeSubscription(name: "Monthly", anchor: D.date(2025, 1, 3), reminder: .oneDay)
        let plans = ReminderPlanner.plan([daily, monthly], now: D.date(2025, 1, 1), minutesAfterMidnight: 540, schedule: D.schedule)
        XCTAssertEqual(plans.count, ReminderPlanner.systemLimit)
        XCTAssertEqual(plans.map(\.fireDate), plans.map(\.fireDate).sorted())
        XCTAssertTrue(plans.contains { $0.name == "Monthly" && $0.chargeDate == D.date(2025, 1, 3) })
        XCTAssertLessThanOrEqual(plans.last?.fireDate ?? .distantFuture, D.date(2025, 3, 5, hour: 9))
    }

    func testNoRemindersForPausedCancelledOrDisabled() {
        let now = D.date(2025, 1, 1)
        let items = [
            makeSubscription(anchor: D.date(2025, 1, 5), reminder: .off),
            makeSubscription(anchor: D.date(2025, 1, 5), reminder: .oneDay, status: .paused, pausedAt: now),
            makeSubscription(anchor: D.date(2025, 1, 5), reminder: .oneDay, status: .cancelled, cancellation: D.date(2025, 2, 1))
        ]
        let plans = ReminderPlanner.plan(items, now: now, minutesAfterMidnight: 540, schedule: D.schedule)
        XCTAssertEqual(plans.map(\.chargeDate), [D.date(2025, 1, 5)])
    }
}

final class AmountParserTests: XCTestCase {
    func testAcceptsCommaAndDot() {
        XCTAssertEqual(AmountParser.parse("9,99"), dec("9.99"))
        XCTAssertEqual(AmountParser.parse("9.99"), dec("9.99"))
        XCTAssertEqual(AmountParser.parse(" 1 500,5 "), dec("1500.5"))
        XCTAssertEqual(AmountParser.parse("2400"), 2400)
    }

    func testRejectsGarbage() {
        XCTAssertNil(AmountParser.parse(""))
        XCTAssertNil(AmountParser.parse("abc"))
        XCTAssertNil(AmountParser.parse("1.2.3"))
        XCTAssertNil(AmountParser.parse("1,234.56"))
        XCTAssertNil(AmountParser.parse("-5"))
        XCTAssertNil(AmountParser.parse("."))
    }
}

final class SubscriptionDraftTests: XCTestCase {
    private func validDraft() -> SubscriptionDraft {
        var draft = SubscriptionDraft()
        draft.name = "Music"
        draft.amountText = "9,99"
        draft.currencyCode = "EUR"
        draft.anchorDate = TestCalendar.date(2025, 1, 31)
        return draft
    }

    func testValidDraftProducesSnapshot() {
        let snapshot = validDraft().snapshot(calendar: TestCalendar.utc)
        XCTAssertEqual(snapshot?.amount, dec("9.99"))
        XCTAssertEqual(snapshot?.period, .monthly)
    }

    func testEmptyNameAndZeroOrNegativeAmountAreRejected() {
        var draft = validDraft()
        draft.name = "   "
        draft.amountText = "0"
        let errors = draft.errors(calendar: TestCalendar.utc)
        XCTAssertEqual(errors[.name], .nameRequired)
        XCTAssertEqual(errors[.amount], .amountNotPositive)
        draft.amountText = "-3"
        XCTAssertEqual(draft.errors(calendar: TestCalendar.utc)[.amount], .amountInvalid)
        XCTAssertNil(draft.snapshot(calendar: TestCalendar.utc))
    }

    func testMaximumAmountAndCurrencyFractionDigits() {
        var draft = validDraft()
        draft.amountText = "9999999.99"
        XCTAssertTrue(draft.isValid(calendar: TestCalendar.utc))
        draft.amountText = "10000000"
        XCTAssertEqual(draft.errors(calendar: TestCalendar.utc)[.amount], .amountTooLarge)
        draft.currencyCode = "JPY"
        draft.amountText = "1500.5"
        XCTAssertEqual(draft.errors(calendar: TestCalendar.utc)[.amount], .tooManyFractionDigits(0))
        draft.amountText = "1500"
        XCTAssertTrue(draft.isValid(calendar: TestCalendar.utc))
    }

    func testCustomPeriodRangeAndTrialValidation() {
        var draft = validDraft()
        draft.preset = .custom
        draft.customUnit = .week
        draft.customCount = 100
        XCTAssertEqual(draft.errors(calendar: TestCalendar.utc)[.count], .countOutOfRange)
        draft.customCount = 2
        XCTAssertEqual(draft.period, BillingPeriod(unit: .week, count: 2))
        draft.hasTrial = true
        draft.trialEndDate = TestCalendar.date(2025, 1, 31)
        XCTAssertEqual(draft.errors(calendar: TestCalendar.utc)[.trial], .trialBeforeAnchor)
        draft.trialEndDate = TestCalendar.date(2025, 2, 14)
        XCTAssertTrue(draft.isValid(calendar: TestCalendar.utc))
    }
}
