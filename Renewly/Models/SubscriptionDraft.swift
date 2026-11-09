import Foundation

enum DraftField: Hashable, Sendable {
    case name
    case amount
    case count
    case trial
}

enum DraftError: Hashable, Sendable {
    case nameRequired
    case amountRequired
    case amountInvalid
    case amountNotPositive
    case amountTooLarge
    case tooManyFractionDigits(Int)
    case countOutOfRange
    case trialBeforeAnchor

    var message: String {
        switch self {
        case .nameRequired: String(localized: "Enter a name.")
        case .amountRequired: String(localized: "Enter an amount.")
        case .amountInvalid: String(localized: "Use digits and one decimal separator, for example 9.99 or 9,99.")
        case .amountNotPositive: String(localized: "The amount must be greater than zero.")
        case .amountTooLarge: String(localized: "The amount can't exceed \(AmountParser.maximum.formatted(.number)).")
        case .tooManyFractionDigits(let digits):
            digits == 0
                ? String(localized: "This currency has no decimal places.")
                : String(localized: "This currency allows at most \(digits) decimal places.")
        case .countOutOfRange: String(localized: "The interval must be between 1 and 99.")
        case .trialBeforeAnchor: String(localized: "The trial must end after the first payment date.")
        }
    }
}

/// Editable form state with validation. Converts to and from `SubscriptionSnapshot`.
struct SubscriptionDraft: Equatable {
    var id = UUID()
    var name = ""
    var amountText = ""
    var currencyCode = CurrencyCatalog.defaultBase
    var preset: BillingPreset = .monthly
    var customCount = 1
    var customUnit: BillingUnit = .month
    var anchorDate = Date.now
    var category: SubscriptionCategory = .streaming
    var note = ""
    var hasTrial = false
    var trialEndDate = Date.now
    var reminder: ReminderOption = .oneDay
    var status: SubscriptionStatus = .active
    var pausedAt: Date?
    var cancellationDate: Date?

    init() {}

    init(snapshot: SubscriptionSnapshot) {
        id = snapshot.id
        name = snapshot.name
        amountText = snapshot.amount.formatted(.number.grouping(.never))
        currencyCode = snapshot.currencyCode
        preset = snapshot.period.preset
        customCount = snapshot.period.count
        customUnit = snapshot.period.unit
        anchorDate = snapshot.anchorDate
        category = snapshot.category
        note = snapshot.note
        hasTrial = snapshot.trialEndDate != nil
        trialEndDate = snapshot.trialEndDate ?? snapshot.anchorDate
        reminder = snapshot.reminder
        status = snapshot.status
        pausedAt = snapshot.pausedAt
        cancellationDate = snapshot.cancellationDate
    }

    var period: BillingPeriod {
        preset.period ?? BillingPeriod(unit: customUnit, count: customCount)
    }

    var amount: Decimal? { AmountParser.parse(amountText) }

    func errors(calendar: Calendar = .current) -> [DraftField: DraftError] {
        var result: [DraftField: DraftError] = [:]
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result[.name] = .nameRequired
        }
        if let amountError = amountError() {
            result[.amount] = amountError
        }
        if preset == .custom, !BillingPeriod.countRange.contains(customCount) {
            result[.count] = .countOutOfRange
        }
        if hasTrial, calendar.startOfDay(for: trialEndDate) <= calendar.startOfDay(for: anchorDate) {
            result[.trial] = .trialBeforeAnchor
        }
        return result
    }

    private func amountError() -> DraftError? {
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .amountRequired }
        guard let value = amount else { return .amountInvalid }
        if value <= 0 { return .amountNotPositive }
        if value > AmountParser.maximum { return .amountTooLarge }
        let allowed = CurrencyCatalog.fractionDigits(for: currencyCode)
        if AmountParser.fractionDigitCount(amountText) > allowed { return .tooManyFractionDigits(allowed) }
        return nil
    }

    func isValid(calendar: Calendar = .current) -> Bool { errors(calendar: calendar).isEmpty }

    /// Nil while the draft is invalid.
    func snapshot(calendar: Calendar = .current) -> SubscriptionSnapshot? {
        guard isValid(calendar: calendar), let amount else { return nil }
        return SubscriptionSnapshot(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            amount: amount,
            currencyCode: currencyCode,
            period: period,
            anchorDate: calendar.startOfDay(for: anchorDate),
            category: category,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            trialEndDate: hasTrial ? calendar.startOfDay(for: trialEndDate) : nil,
            reminder: reminder,
            status: status,
            pausedAt: pausedAt,
            cancellationDate: cancellationDate
        )
    }
}
