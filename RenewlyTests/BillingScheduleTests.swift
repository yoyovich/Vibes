import XCTest
@testable import Renewly

final class BillingScheduleTests: XCTestCase {
    private let schedule = TestCalendar.schedule
    private typealias D = TestCalendar

    func testJanuary31MonthlyClampsToMonthEndWithoutDrift() {
        let subscription = makeSubscription(anchor: D.date(2025, 1, 31))
        let charges = schedule.upcomingCharges(of: subscription, now: D.date(2025, 2, 1), count: 4)
        XCTAssertEqual(charges, [D.date(2025, 2, 28), D.date(2025, 3, 31), D.date(2025, 4, 30), D.date(2025, 5, 31)])
    }

    func testJanuary31MonthlyInLeapYearUsesFebruary29() {
        let subscription = makeSubscription(anchor: D.date(2024, 1, 31))
        let charges = schedule.upcomingCharges(of: subscription, now: D.date(2024, 2, 1), count: 3)
        XCTAssertEqual(charges, [D.date(2024, 2, 29), D.date(2024, 3, 31), D.date(2024, 4, 30)])
    }

    func testMonthWithThirtyOneToThirtyDays() {
        let subscription = makeSubscription(anchor: D.date(2025, 3, 31))
        XCTAssertEqual(schedule.nextCharge(of: subscription, now: D.date(2025, 4, 1)), D.date(2025, 4, 30))
        XCTAssertEqual(schedule.nextCharge(of: subscription, now: D.date(2025, 5, 1)), D.date(2025, 5, 31))
    }

    func testYearlyFebruary29FallsBackToFebruary28() {
        let subscription = makeSubscription(period: .yearly, anchor: D.date(2024, 2, 29))
        let charges = schedule.upcomingCharges(of: subscription, now: D.date(2024, 3, 1), count: 4)
        XCTAssertEqual(charges, [D.date(2025, 2, 28), D.date(2026, 2, 28), D.date(2027, 2, 28), D.date(2028, 2, 29)])
    }

    func testQuarterlyAcrossYearBoundary() {
        let subscription = makeSubscription(period: .quarterly, anchor: D.date(2024, 11, 30))
        let charges = schedule.upcomingCharges(of: subscription, now: D.date(2024, 12, 1), count: 3)
        XCTAssertEqual(charges, [D.date(2025, 2, 28), D.date(2025, 5, 30), D.date(2025, 8, 30)])
    }

    func testEveryTwoMonthsFromAugust31() {
        let subscription = makeSubscription(period: BillingPeriod(unit: .month, count: 2), anchor: D.date(2025, 8, 31))
        let charges = schedule.upcomingCharges(of: subscription, now: D.date(2025, 9, 1), count: 3)
        XCTAssertEqual(charges, [D.date(2025, 10, 31), D.date(2025, 12, 31), D.date(2026, 2, 28)])
    }

    func testWeeklyCrossesYear() {
        let subscription = makeSubscription(period: .weekly, anchor: D.date(2025, 12, 25))
        let charges = schedule.upcomingCharges(of: subscription, now: D.date(2025, 12, 26), count: 2)
        XCTAssertEqual(charges, [D.date(2026, 1, 1), D.date(2026, 1, 8)])
    }

    func testFutureAnchorIsTheNextCharge() {
        let subscription = makeSubscription(anchor: D.date(2026, 3, 15))
        XCTAssertEqual(schedule.nextCharge(of: subscription, now: D.date(2026, 1, 10, hour: 18)), D.date(2026, 3, 15))
    }

    func testChargeDueTodayIsNext() {
        let subscription = makeSubscription(anchor: D.date(2025, 1, 10))
        XCTAssertEqual(schedule.nextCharge(of: subscription, now: D.date(2025, 6, 10, hour: 23)), D.date(2025, 6, 10))
    }

    func testDistantAnchorWithDailyPeriodSkipsAheadCorrectly() {
        let subscription = makeSubscription(period: BillingPeriod(unit: .day, count: 3), anchor: D.date(2015, 1, 1))
        let next = schedule.nextCharge(of: subscription, now: D.date(2025, 1, 1))
        // 3653 days between the dates; the next multiple of 3 is 3654.
        XCTAssertEqual(next, D.date(2025, 1, 2))
    }

    func testTrialDelaysFirstChargeAndRestartsCycle() {
        let subscription = makeSubscription(anchor: D.date(2025, 1, 10), trialEnd: D.date(2025, 1, 31))
        XCTAssertEqual(schedule.nextCharge(of: subscription, now: D.date(2025, 1, 15)), D.date(2025, 1, 31))
        XCTAssertEqual(schedule.upcomingCharges(of: subscription, now: D.date(2025, 2, 1), count: 2), [D.date(2025, 2, 28), D.date(2025, 3, 31)])
        XCTAssertEqual(schedule.pastCharges(of: subscription, now: D.date(2025, 1, 30)), [])
    }

    func testPausedSubscriptionHasNoFutureCharges() {
        let subscription = makeSubscription(anchor: D.date(2025, 1, 1), status: .paused, pausedAt: D.date(2025, 3, 15))
        XCTAssertNil(schedule.nextCharge(of: subscription, now: D.date(2025, 4, 1)))
        XCTAssertFalse(schedule.isInEffect(subscription, now: D.date(2025, 4, 1)))
        XCTAssertEqual(schedule.pastCharges(of: subscription, now: D.date(2025, 4, 1)).count, 3)
    }

    func testCancelledSubscriptionRunsUntilCancellationDate() {
        let subscription = makeSubscription(anchor: D.date(2025, 1, 5), status: .cancelled, cancellation: D.date(2025, 3, 20))
        XCTAssertTrue(schedule.isInEffect(subscription, now: D.date(2025, 3, 1)))
        XCTAssertEqual(schedule.nextCharge(of: subscription, now: D.date(2025, 3, 1)), D.date(2025, 3, 5))
        XCTAssertNil(schedule.nextCharge(of: subscription, now: D.date(2025, 3, 6)))
        XCTAssertFalse(schedule.isInEffect(subscription, now: D.date(2025, 3, 20)))
    }

    func testTotalSpentCountsPastChargesIncludingToday() {
        let subscription = makeSubscription(amount: "9.99", anchor: D.date(2025, 1, 31))
        // Jan 31, Feb 28, Mar 31, Apr 30.
        XCTAssertEqual(schedule.totalSpent(of: subscription, now: D.date(2025, 4, 30, hour: 8)), dec("39.96"))
    }

    func testDaysUntilIgnoresTimeOfDay() {
        XCTAssertEqual(schedule.daysUntil(D.date(2025, 3, 2), now: D.date(2025, 2, 28, hour: 23)), 2)
    }
}
