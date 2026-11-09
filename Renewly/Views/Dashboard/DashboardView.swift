import SwiftData
import SwiftUI

struct DashboardView: View {
    @Binding var selectedTab: AppTab
    @Environment(\.currencyConverter) private var converter
    @Query(sort: \SubscriptionItem.name) private var items: [SubscriptionItem]
    @State private var isAddingSubscription = false

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    NoSubscriptionsView(onAdd: { isAddingSubscription = true })
                } else {
                    content
                }
            }
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAddingSubscription = true
                    } label: {
                        Label("Add subscription", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: SubscriptionItem.self) { item in
                SubscriptionDetailView(item: item)
            }
            .sheet(isPresented: $isAddingSubscription) {
                SubscriptionFormView(item: nil)
            }
        }
    }

    private var content: some View {
        let now = Date.now
        let logic = LogicContext(converter: converter)
        let snapshots = items.map(\.snapshot)
        let analytics = logic.analytics
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return List {
            Section {
                TotalsCard(
                    monthly: analytics.monthlyTotal(snapshots, now: now),
                    yearly: analytics.yearlyTotal(snapshots, now: now),
                    currencyCode: converter.baseCode,
                    hasMissingRates: analytics.hasMissingRates(snapshots, now: now)
                )
            }
            Section("Spending by category") {
                CategoryMiniChart(totals: analytics.categoryTotals(snapshots, now: now), currencyCode: converter.baseCode)
                Button("Show statistics") { selectedTab = .statistics }
            }
            Section("Upcoming charges · 30 days") {
                let upcoming = analytics.upcoming(snapshots, now: now)
                if upcoming.isEmpty {
                    ContentUnavailableView(
                        "No charges in the next 30 days",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("Paused and cancelled subscriptions aren't charged.")
                    )
                } else {
                    ForEach(upcoming) { charge in
                        if let item = byID[charge.subscriptionID] {
                            NavigationLink(value: item) {
                                UpcomingChargeRow(charge: charge, category: item.category)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct TotalsCard: View {
    let monthly: Decimal
    let yearly: Decimal
    let currencyCode: String
    let hasMissingRates: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(monthly.currencyText(currencyCode))
                .font(.largeTitle.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(2)
            Text("Per year: \(yearly.currencyText(currencyCode))")
                .font(.headline)
                .foregroundStyle(.secondary)
            if hasMissingRates {
                RateMissingBadge()
                Text("Some subscriptions are converted at a rate of 1. Set rates in Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct UpcomingChargeRow: View {
    let charge: UpcomingCharge
    let category: SubscriptionCategory

    var body: some View {
        HStack(spacing: 12) {
            CategoryIcon(category: category)
            VStack(alignment: .leading, spacing: 2) {
                Text(charge.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(charge.date.dayText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(charge.amount.currencyText(charge.currencyCode))
                    .font(.body.monospacedDigit())
                DaysLeftText(days: charge.daysLeft)
                    .font(.caption)
                    .foregroundStyle(charge.daysLeft <= 3 ? .orange : .secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct DaysLeftText: View {
    let days: Int

    var body: some View {
        switch days {
        case ..<1: Text("Today")
        case 1: Text("Tomorrow")
        default: Text("In \(days) days")
        }
    }
}

/// Shown on screens that need subscriptions when there are none at all.
struct NoSubscriptionsView: View {
    let onAdd: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Environment(\.currencyConverter) private var converter

    var body: some View {
        ContentUnavailableView {
            Label("No subscriptions yet", systemImage: "creditcard.and.123")
        } description: {
            Text("Add the services you pay for to see monthly spending and upcoming charges.")
        } actions: {
            Button("Add subscription", action: onAdd)
                .buttonStyle(.borderedProminent)
            Button("Load demo data") {
                DataStore(context: context, errors: errors).loadDemo(converter: converter, now: .now)
            }
            .buttonStyle(.bordered)
        }
    }
}
