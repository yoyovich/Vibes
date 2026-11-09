import Foundation

/// Calendar unit a billing cycle is measured in.
enum BillingUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month
    case year

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .day: "Days"
        case .week: "Weeks"
        case .month: "Months"
        case .year: "Years"
        }
    }
}

/// A billing cycle such as "every 3 months".
struct BillingPeriod: Hashable, Codable, Sendable {
    static let countRange = 1...99

    static let weekly = BillingPeriod(unit: .week, count: 1)
    static let monthly = BillingPeriod(unit: .month, count: 1)
    static let quarterly = BillingPeriod(unit: .month, count: 3)
    static let yearly = BillingPeriod(unit: .year, count: 1)

    var unit: BillingUnit
    var count: Int

    var preset: BillingPreset {
        switch self {
        case .weekly: .weekly
        case .monthly: .monthly
        case .quarterly: .quarterly
        case .yearly: .yearly
        default: .custom
        }
    }

    var title: String {
        switch preset {
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        case .quarterly: return String(localized: "Quarterly")
        case .yearly: return String(localized: "Yearly")
        case .custom:
            switch unit {
            case .day: return String(localized: "Every \(count) days")
            case .week: return String(localized: "Every \(count) weeks")
            case .month: return String(localized: "Every \(count) months")
            case .year: return String(localized: "Every \(count) years")
            }
        }
    }
}

/// Choices offered in the form and the list filter.
enum BillingPreset: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case monthly
    case quarterly
    case yearly
    case custom

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .quarterly: "Quarterly"
        case .yearly: "Yearly"
        case .custom: "Custom"
        }
    }

    var period: BillingPeriod? {
        switch self {
        case .weekly: .weekly
        case .monthly: .monthly
        case .quarterly: .quarterly
        case .yearly: .yearly
        case .custom: nil
        }
    }
}
