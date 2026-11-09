import Foundation
import SwiftData

/// Persistent subscription record.
@Model
final class SubscriptionItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var currencyCode: String
    var periodUnitRaw: String
    var periodCount: Int
    var anchorDate: Date
    var categoryRaw: String
    var note: String
    var trialEndDate: Date?
    var reminderDays: Int
    var statusRaw: String
    var pausedAt: Date?
    var cancellationDate: Date?
    var createdAt: Date

    init(snapshot: SubscriptionSnapshot, createdAt: Date = .now) {
        id = snapshot.id
        name = snapshot.name
        amount = snapshot.amount
        currencyCode = snapshot.currencyCode
        periodUnitRaw = snapshot.period.unit.rawValue
        periodCount = snapshot.period.count
        anchorDate = snapshot.anchorDate
        categoryRaw = snapshot.category.rawValue
        note = snapshot.note
        trialEndDate = snapshot.trialEndDate
        reminderDays = snapshot.reminder.rawValue
        statusRaw = snapshot.status.rawValue
        pausedAt = snapshot.pausedAt
        cancellationDate = snapshot.cancellationDate
        self.createdAt = createdAt
    }

    var period: BillingPeriod {
        BillingPeriod(unit: BillingUnit(rawValue: periodUnitRaw) ?? .month, count: max(periodCount, 1))
    }

    var category: SubscriptionCategory { SubscriptionCategory(rawValue: categoryRaw) ?? .other }

    var status: SubscriptionStatus { SubscriptionStatus(rawValue: statusRaw) ?? .active }

    var reminder: ReminderOption { ReminderOption(rawValue: reminderDays) ?? .off }

    var snapshot: SubscriptionSnapshot {
        SubscriptionSnapshot(
            id: id,
            name: name,
            amount: amount,
            currencyCode: currencyCode,
            period: period,
            anchorDate: anchorDate,
            category: category,
            note: note,
            trialEndDate: trialEndDate,
            reminder: reminder,
            status: status,
            pausedAt: pausedAt,
            cancellationDate: cancellationDate
        )
    }

    /// Copies every user-editable field. Status fields are only copied when requested.
    func apply(_ snapshot: SubscriptionSnapshot, includingStatus: Bool) {
        name = snapshot.name
        amount = snapshot.amount
        currencyCode = snapshot.currencyCode
        periodUnitRaw = snapshot.period.unit.rawValue
        periodCount = snapshot.period.count
        anchorDate = snapshot.anchorDate
        categoryRaw = snapshot.category.rawValue
        note = snapshot.note
        trialEndDate = snapshot.trialEndDate
        reminderDays = snapshot.reminder.rawValue
        if includingStatus {
            statusRaw = snapshot.status.rawValue
            pausedAt = snapshot.pausedAt
            cancellationDate = snapshot.cancellationDate
        }
    }

    func pause(at date: Date) {
        statusRaw = SubscriptionStatus.paused.rawValue
        pausedAt = date
        cancellationDate = nil
    }

    func resume() {
        statusRaw = SubscriptionStatus.active.rawValue
        pausedAt = nil
        cancellationDate = nil
    }

    func cancel(on date: Date) {
        statusRaw = SubscriptionStatus.cancelled.rawValue
        pausedAt = nil
        cancellationDate = date
    }
}

/// Manually entered rate: one unit of `currencyCode` equals `rate` units of the base currency.
@Model
final class CurrencyRate {
    @Attribute(.unique) var currencyCode: String
    var rate: Decimal

    init(currencyCode: String, rate: Decimal) {
        self.currencyCode = currencyCode
        self.rate = rate
    }
}
