import Foundation

struct UpcomingCharge: Identifiable, Hashable, Sendable {
    let subscriptionID: UUID
    let name: String
    let date: Date
    let amount: Decimal
    let currencyCode: String
    let daysLeft: Int

    var id: String { "\(subscriptionID.uuidString)-\(date.timeIntervalSinceReferenceDate)" }
}

struct CategoryAmount: Identifiable, Hashable, Sendable {
    let category: SubscriptionCategory
    let amount: Decimal

    var id: String { category.rawValue }
}

struct ForecastEntry: Identifiable, Hashable, Sendable {
    let month: Date
    let category: SubscriptionCategory
    let amount: Decimal

    var id: String { "\(month.timeIntervalSinceReferenceDate)-\(category.rawValue)" }
}

struct RankedSubscription: Identifiable, Hashable, Sendable {
    let subscription: SubscriptionSnapshot
    let monthlyInBase: Decimal

    var id: UUID { subscription.id }
}

/// Aggregations shown on the dashboard and statistics screens, all in the base currency.
struct SpendingAnalytics: Sendable {
    let schedule: BillingSchedule
    let converter: CurrencyConverter

    func monthlyInBase(_ subscription: SubscriptionSnapshot) -> Decimal {
        converter.convert(BillingSchedule.monthlyCost(of: subscription), from: subscription.currencyCode)
    }

    func inEffect(_ subscriptions: [SubscriptionSnapshot], now: Date) -> [SubscriptionSnapshot] {
        subscriptions.filter { schedule.isInEffect($0, now: now) }
    }

    func monthlyTotal(_ subscriptions: [SubscriptionSnapshot], now: Date) -> Decimal {
        inEffect(subscriptions, now: now).reduce(Decimal(0)) { $0 + monthlyInBase($1) }
    }

    func yearlyTotal(_ subscriptions: [SubscriptionSnapshot], now: Date) -> Decimal {
        monthlyTotal(subscriptions, now: now) * 12
    }

    func hasMissingRates(_ subscriptions: [SubscriptionSnapshot], now: Date) -> Bool {
        inEffect(subscriptions, now: now).contains { converter.isRateMissing(for: $0.currencyCode) }
    }

    func upcoming(_ subscriptions: [SubscriptionSnapshot], now: Date, days: Int = 30) -> [UpcomingCharge] {
        let calendar = schedule.calendar
        let today = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: days + 1, to: today) else { return [] }
        return subscriptions
            .flatMap { subscription in
                schedule.charges(of: subscription, from: today, to: end, now: now).map { date in
                    UpcomingCharge(
                        subscriptionID: subscription.id,
                        name: subscription.name,
                        date: date,
                        amount: subscription.amount,
                        currencyCode: subscription.currencyCode,
                        daysLeft: schedule.daysUntil(date, now: now)
                    )
                }
            }
            .sorted { ($0.date, $0.name) < ($1.date, $1.name) }
    }

    func categoryTotals(_ subscriptions: [SubscriptionSnapshot], now: Date) -> [CategoryAmount] {
        let grouped = Dictionary(grouping: inEffect(subscriptions, now: now), by: \.category)
        return grouped
            .map { CategoryAmount(category: $0.key, amount: $0.value.reduce(Decimal(0)) { $0 + monthlyInBase($1) }) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    /// Real charges per calendar month for the current month and the following ones.
    /// The current month only includes charges from today on.
    func forecast(_ subscriptions: [SubscriptionSnapshot], now: Date, months: Int) -> [ForecastEntry] {
        let calendar = schedule.calendar
        let today = calendar.startOfDay(for: now)
        guard let firstMonth = calendar.dateInterval(of: .month, for: today)?.start else { return [] }
        var entries: [ForecastEntry] = []
        for offset in 0..<max(months, 0) {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: firstMonth),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
            else { continue }
            let lower = max(monthStart, today)
            var sums: [SubscriptionCategory: Decimal] = [:]
            for subscription in subscriptions {
                let count = schedule.charges(of: subscription, from: lower, to: monthEnd, now: now).count
                guard count > 0 else { continue }
                let amount = converter.convert(subscription.amount * Decimal(count), from: subscription.currencyCode)
                sums[subscription.category, default: 0] += amount
            }
            for category in SubscriptionCategory.allCases {
                if let amount = sums[category] {
                    entries.append(ForecastEntry(month: monthStart, category: category, amount: amount))
                }
            }
        }
        return entries
    }

    func mostExpensive(_ subscriptions: [SubscriptionSnapshot], now: Date, limit: Int = 5) -> [RankedSubscription] {
        inEffect(subscriptions, now: now)
            .map { RankedSubscription(subscription: $0, monthlyInBase: monthlyInBase($0)) }
            .sorted { $0.monthlyInBase == $1.monthlyInBase ? $0.subscription.name < $1.subscription.name : $0.monthlyInBase > $1.monthlyInBase }
            .prefix(limit)
            .map { $0 }
    }
}
