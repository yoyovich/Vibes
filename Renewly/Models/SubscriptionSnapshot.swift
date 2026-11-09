import Foundation

/// Immutable value copy of a subscription. All business logic works on this type,
/// so it stays independent from SwiftData and SwiftUI.
struct SubscriptionSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var amount: Decimal
    var currencyCode: String
    var period: BillingPeriod
    var anchorDate: Date
    var category: SubscriptionCategory
    var note: String
    var trialEndDate: Date?
    var reminder: ReminderOption
    var status: SubscriptionStatus
    var pausedAt: Date?
    var cancellationDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        currencyCode: String,
        period: BillingPeriod,
        anchorDate: Date,
        category: SubscriptionCategory = .other,
        note: String = "",
        trialEndDate: Date? = nil,
        reminder: ReminderOption = .off,
        status: SubscriptionStatus = .active,
        pausedAt: Date? = nil,
        cancellationDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.currencyCode = currencyCode
        self.period = period
        self.anchorDate = anchorDate
        self.category = category
        self.note = note
        self.trialEndDate = trialEndDate
        self.reminder = reminder
        self.status = status
        self.pausedAt = pausedAt
        self.cancellationDate = cancellationDate
    }
}
