import Foundation

struct ReminderPlan: Identifiable, Hashable, Sendable {
    let subscriptionID: UUID
    let name: String
    let amount: Decimal
    let currencyCode: String
    let chargeDate: Date
    let fireDate: Date
    let daysBefore: Int

    var id: String { "renewly.\(subscriptionID.uuidString).\(Int(chargeDate.timeIntervalSince1970))" }
}

/// Decides which local notifications to schedule. iOS keeps at most 64 pending ones per app.
enum ReminderPlanner {
    static let systemLimit = 64

    static func plan(
        _ subscriptions: [SubscriptionSnapshot],
        now: Date,
        minutesAfterMidnight: Int,
        schedule: BillingSchedule,
        limit: Int = systemLimit,
        horizonDays: Int = 400
    ) -> [ReminderPlan] {
        let calendar = schedule.calendar
        let today = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(byAdding: .day, value: horizonDays, to: today) else { return [] }
        let hour = min(max(minutesAfterMidnight / 60, 0), 23)
        let minute = min(max(minutesAfterMidnight % 60, 0), 59)

        var plans: [ReminderPlan] = []
        for subscription in subscriptions {
            guard let days = subscription.reminder.daysBefore else { continue }
            var perSubscription = 0
            for charge in schedule.charges(of: subscription, from: today, to: horizon, now: now) {
                guard perSubscription < limit,
                      let fireDay = calendar.date(byAdding: .day, value: -days, to: charge),
                      let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: fireDay),
                      fireDate > now
                else { continue }
                plans.append(ReminderPlan(
                    subscriptionID: subscription.id,
                    name: subscription.name,
                    amount: subscription.amount,
                    currencyCode: subscription.currencyCode,
                    chargeDate: charge,
                    fireDate: fireDate,
                    daysBefore: days
                ))
                perSubscription += 1
            }
        }
        plans.sort { lhs, rhs in
            lhs.fireDate == rhs.fireDate ? lhs.name < rhs.name : lhs.fireDate < rhs.fireDate
        }
        return Array(plans.prefix(limit))
    }
}
