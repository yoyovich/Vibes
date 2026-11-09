import Foundation

/// Date and cost rules for subscriptions. Pure: the current time is always passed in.
struct BillingSchedule: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    // MARK: Cost

    /// Monthly equivalent of a price: week = ×52/12, day = ×(365/12), year = ÷12, every N units = ÷N.
    static func monthlyCost(amount: Decimal, period: BillingPeriod) -> Decimal {
        let count = Decimal(max(period.count, 1))
        switch period.unit {
        case .day: return amount * 365 / 12 / count
        case .week: return amount * 52 / 12 / count
        case .month: return amount / count
        case .year: return amount / 12 / count
        }
    }

    static func monthlyCost(of subscription: SubscriptionSnapshot) -> Decimal {
        monthlyCost(amount: subscription.amount, period: subscription.period)
    }

    // MARK: Raw cycle

    /// The date the cycle is counted from: the end of a trial when there is one, otherwise the anchor.
    func cycleStart(of subscription: SubscriptionSnapshot) -> Date {
        let anchor = calendar.startOfDay(for: subscription.anchorDate)
        if let trialEnd = subscription.trialEndDate {
            let trialDay = calendar.startOfDay(for: trialEnd)
            if trialDay > anchor { return trialDay }
        }
        return anchor
    }

    /// The n-th charge, always computed from the cycle start so month-end clamping never drifts
    /// (Jan 31 → Feb 28/29 → Mar 31 → Apr 30).
    func occurrence(_ index: Int, of subscription: SubscriptionSnapshot) -> Date? {
        let start = cycleStart(of: subscription)
        let step = max(subscription.period.count, 1) * index
        switch subscription.period.unit {
        case .day: return calendar.date(byAdding: .day, value: step, to: start)
        case .week: return calendar.date(byAdding: .day, value: step * 7, to: start)
        case .month: return calendar.date(byAdding: .month, value: step, to: start)
        case .year: return calendar.date(byAdding: .year, value: step, to: start)
        }
    }

    /// Index of a charge that is guaranteed to be on or before `day`, used to skip ahead quickly.
    private func estimatedIndex(before day: Date, of subscription: SubscriptionSnapshot) -> Int {
        let start = cycleStart(of: subscription)
        guard day > start else { return 0 }
        let count = max(subscription.period.count, 1)
        let units: Int
        switch subscription.period.unit {
        case .day: units = calendar.dateComponents([.day], from: start, to: day).day ?? 0
        case .week: units = (calendar.dateComponents([.day], from: start, to: day).day ?? 0) / 7
        case .month: units = calendar.dateComponents([.month], from: start, to: day).month ?? 0
        case .year: units = calendar.dateComponents([.year], from: start, to: day).year ?? 0
        }
        return max(units / count - 1, 0)
    }

    // MARK: Status-aware charges

    /// Day before which charges actually happen. Nil means "no limit".
    func chargeLimit(of subscription: SubscriptionSnapshot, now: Date) -> Date? {
        switch subscription.status {
        case .active:
            return nil
        case .paused:
            return calendar.startOfDay(for: subscription.pausedAt ?? now)
        case .cancelled:
            return calendar.startOfDay(for: subscription.cancellationDate ?? now)
        }
    }

    /// Charges that really happen in `[from, to)`, respecting trial, pause and cancellation.
    func charges(of subscription: SubscriptionSnapshot, from: Date, to: Date, now: Date, limit: Int = 10_000) -> [Date] {
        var upper = to
        if let stop = chargeLimit(of: subscription, now: now) {
            upper = min(upper, stop)
        }
        let lower = calendar.startOfDay(for: from)
        guard lower < upper else { return [] }
        var result: [Date] = []
        var index = estimatedIndex(before: lower, of: subscription)
        while result.count < limit, let date = occurrence(index, of: subscription), date < upper {
            if date >= lower { result.append(date) }
            index += 1
        }
        return result
    }

    /// Whether the subscription currently counts in totals: active, or cancelled but still running.
    func isInEffect(_ subscription: SubscriptionSnapshot, now: Date) -> Bool {
        switch subscription.status {
        case .active: return true
        case .paused: return false
        case .cancelled:
            guard let date = subscription.cancellationDate else { return false }
            return calendar.startOfDay(for: now) < calendar.startOfDay(for: date)
        }
    }

    /// Next real charge on or after today, nil if none will happen.
    func nextCharge(of subscription: SubscriptionSnapshot, now: Date) -> Date? {
        upcomingCharges(of: subscription, now: now, count: 1).first
    }

    func upcomingCharges(of subscription: SubscriptionSnapshot, now: Date, count: Int) -> [Date] {
        let today = calendar.startOfDay(for: now)
        guard let horizon = calendar.date(byAdding: .year, value: 100, to: today) else { return [] }
        return charges(of: subscription, from: today, to: horizon, now: now, limit: count)
    }

    /// Charges that already happened (including today) since the anchor date.
    func pastCharges(of subscription: SubscriptionSnapshot, now: Date) -> [Date] {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else { return [] }
        return charges(of: subscription, from: cycleStart(of: subscription), to: tomorrow, now: now)
    }

    func totalSpent(of subscription: SubscriptionSnapshot, now: Date) -> Decimal {
        Decimal(pastCharges(of: subscription, now: now).count) * subscription.amount
    }

    func daysUntil(_ date: Date, now: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }
}
