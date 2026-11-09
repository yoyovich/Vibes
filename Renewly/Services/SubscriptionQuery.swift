import Foundation

enum SubscriptionSort: String, CaseIterable, Identifiable, Sendable {
    case nextCharge
    case monthlyCost
    case name

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .nextCharge: "Next charge"
        case .monthlyCost: "Cost per month"
        case .name: "Name"
        }
    }
}

/// Search, filter and sort settings of the subscription list.
struct SubscriptionQuery: Hashable, Sendable {
    var searchText = ""
    var status: SubscriptionStatus?
    var category: SubscriptionCategory?
    var preset: BillingPreset?
    var sort: SubscriptionSort = .nextCharge

    var hasActiveFilters: Bool {
        status != nil || category != nil || preset != nil
    }

    private func matches(_ item: SubscriptionSnapshot, needle: String) -> Bool {
        if !needle.isEmpty, !item.name.localizedStandardContains(needle) { return false }
        if let status, item.status != status { return false }
        if let category, item.category != category { return false }
        if let preset, item.period.preset != preset { return false }
        return true
    }

    func apply(to subscriptions: [SubscriptionSnapshot], analytics: SpendingAnalytics, now: Date) -> [SubscriptionSnapshot] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = subscriptions.filter { item in matches(item, needle: needle) }
        switch sort {
        case .name:
            return filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .monthlyCost:
            return filtered.sorted { analytics.monthlyInBase($0) > analytics.monthlyInBase($1) }
        case .nextCharge:
            let next = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, analytics.schedule.nextCharge(of: $0, now: now)) })
            return filtered.sorted { lhs, rhs in
                switch (next[lhs.id] ?? nil, next[rhs.id] ?? nil) {
                case let (left?, right?): return left == right ? lhs.name < rhs.name : left < right
                case (.some, .none): return true
                case (.none, .some): return false
                case (.none, .none): return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }
        }
    }
}
