import Foundation

enum SubscriptionStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case paused
    case cancelled

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .cancelled: "Cancelled"
        }
    }
}

/// How many days before a charge the user wants to be reminded.
enum ReminderOption: Int, Codable, CaseIterable, Identifiable, Sendable {
    case off = -1
    case sameDay = 0
    case oneDay = 1
    case threeDays = 3
    case oneWeek = 7

    var id: Int { rawValue }

    var daysBefore: Int? { self == .off ? nil : rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .off: "No reminder"
        case .sameDay: "On the day"
        case .oneDay: "1 day before"
        case .threeDays: "3 days before"
        case .oneWeek: "7 days before"
        }
    }
}
