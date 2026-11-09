import Foundation
@testable import Renewly

enum TestCalendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    static let schedule = BillingSchedule(calendar: utc)

    static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        guard let date = utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) else {
            preconditionFailure("Invalid test date")
        }
        return date
    }
}

func dec(_ text: String) -> Decimal {
    guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
        preconditionFailure("Invalid decimal literal")
    }
    return value
}

func makeSubscription(
    name: String = "Test",
    amount: String = "10",
    currency: String = "USD",
    period: BillingPeriod = .monthly,
    anchor: Date,
    category: SubscriptionCategory = .other,
    trialEnd: Date? = nil,
    reminder: ReminderOption = .off,
    status: SubscriptionStatus = .active,
    pausedAt: Date? = nil,
    cancellation: Date? = nil
) -> SubscriptionSnapshot {
    SubscriptionSnapshot(
        name: name,
        amount: dec(amount),
        currencyCode: currency,
        period: period,
        anchorDate: anchor,
        category: category,
        trialEndDate: trialEnd,
        reminder: reminder,
        status: status,
        pausedAt: pausedAt,
        cancellationDate: cancellation
    )
}
