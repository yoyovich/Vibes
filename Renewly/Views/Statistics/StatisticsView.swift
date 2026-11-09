import SwiftData
import SwiftUI

enum ForecastRange: Int, CaseIterable, Identifiable {
    case three = 3
    case six = 6
    case twelve = 12

    var id: Int { rawValue }
}

struct StatisticsView: View {
    @Environment(\.currencyConverter) private var converter
    @Query private var items: [SubscriptionItem]
    @State private var range: ForecastRange = .six

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Statistics")
        }
    }

    @ViewBuilder
    private var content: some View {
        let now = Date.now
        let analytics = LogicContext(converter: converter).analytics
        let snapshots = items.map(\.snapshot)
        let forecast = analytics.forecast(snapshots, now: now, months: range.rawValue)
        let shares = analytics.categoryTotals(snapshots, now: now)
        let top = analytics.mostExpensive(snapshots, now: now)
        let base = converter.baseCode

        if forecast.isEmpty && shares.isEmpty {
            ContentUnavailableView(
                "No data for statistics",
                systemImage: "chart.bar.xaxis",
                description: Text("Add an active subscription or load demo data in Settings.")
            )
        } else {
            List {
                Section {
                    Picker("Period", selection: $range) {
                        ForEach(ForecastRange.allCases) { option in
                            Text("\(option.rawValue) months").tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    ForecastChart(entries: forecast, currencyCode: base)
                    ValueRow(title: Text("Total for the period")) {
                        Text(forecast.reduce(Decimal(0)) { $0 + $1.amount }.currencyText(base))
                            .bold()
                    }
                } header: {
                    Text("Forecast by month")
                } footer: {
                    Text("Real charge dates, including trials, pauses and cancellations. The current month starts today.")
                }

                Section("Share by category · per month") {
                    CategorySharesChart(totals: shares, currencyCode: base)
                }

                Section("Top 5 most expensive · per month") {
                    if top.isEmpty {
                        Text("No active subscriptions")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, entry in
                            HStack(spacing: 12) {
                                Text("\(index + 1).")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                CategoryIcon(category: entry.subscription.category)
                                Text(entry.subscription.name)
                                    .lineLimit(2)
                                Spacer(minLength: 8)
                                Text(entry.monthlyInBase.currencyText(base))
                                    .font(.body.monospacedDigit())
                                    .multilineTextAlignment(.trailing)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
    }
}
