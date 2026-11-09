import XCTest
@testable import Renewly

final class MonthlyCostTests: XCTestCase {
    func testWeeklyUsesFiftyTwoWeeksPerYear() {
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 12, period: .weekly), 52)
    }

    func testMonthlyIsUnchanged() {
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: dec("9.99"), period: .monthly), dec("9.99"))
    }

    func testQuarterlyIsDividedByThree() {
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 30, period: .quarterly), 10)
    }

    func testYearlyIsDividedByTwelve() {
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 120, period: .yearly), 10)
    }

    func testCustomPeriodsDivideByCount() {
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 12, period: BillingPeriod(unit: .week, count: 2)), 26)
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 60, period: BillingPeriod(unit: .month, count: 6)), 10)
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 240, period: BillingPeriod(unit: .year, count: 2)), 10)
    }

    func testDailyUsesThreeHundredSixtyFiveTwelfths() {
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 12, period: BillingPeriod(unit: .day, count: 1)), 365)
        XCTAssertEqual(BillingSchedule.monthlyCost(amount: 120, period: BillingPeriod(unit: .day, count: 10)), 365)
    }

    func testLargeAmountKeepsPrecision() {
        let monthly = BillingSchedule.monthlyCost(amount: dec("9999999.99"), period: .yearly)
        XCTAssertEqual(monthly.rounded(scale: 2), dec("833333.33"))
    }
}
