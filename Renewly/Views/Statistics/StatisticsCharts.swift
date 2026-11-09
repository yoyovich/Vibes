import Charts
import SwiftUI

struct ForecastChart: View {
    let entries: [ForecastEntry]
    let currencyCode: String
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 240

    private var categories: [SubscriptionCategory] {
        SubscriptionCategory.allCases.filter { category in entries.contains { $0.category == category } }
    }

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No charges in this period",
                systemImage: "calendar",
                description: Text("Paused and cancelled subscriptions aren't charged.")
            )
        } else {
            Chart(entries) { entry in
                BarMark(
                    x: .value("Month", entry.month, unit: .month),
                    y: .value("Amount", entry.amount.doubleValue)
                )
                .foregroundStyle(by: .value("Category", entry.category.localizedTitle))
                .accessibilityLabel(Text("\(entry.month.formatted(.dateTime.month(.wide).year())), \(entry.category.localizedTitle)"))
                .accessibilityValue(Text(entry.amount.currencyText(currencyCode)))
            }
            .chartForegroundStyleScale(
                domain: categories.map(\.localizedTitle),
                range: categories.map(\.color)
            )
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(amount, format: .currency(code: currencyCode).precision(.fractionLength(0)))
                        }
                    }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(minHeight: height)
            .padding(.vertical, 6)
        }
    }
}

struct CategorySharesChart: View {
    let totals: [CategoryAmount]
    let currencyCode: String
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 220

    var body: some View {
        if totals.isEmpty {
            ContentUnavailableView(
                "No active spending",
                systemImage: "chart.pie",
                description: Text("Active subscriptions will appear here.")
            )
        } else {
            let total = totals.reduce(Decimal(0)) { $0 + $1.amount }
            Chart(totals) { entry in
                SectorMark(
                    angle: .value("Amount", entry.amount.doubleValue),
                    innerRadius: .ratio(0.6),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(entry.category.color)
                .accessibilityLabel(Text(entry.category.localizedTitle))
                .accessibilityValue(Text(entry.amount.currencyText(currencyCode)))
            }
            .chartBackground { proxy in
                GeometryReader { geometry in
                    if let frame = proxy.plotFrame {
                        let rect = geometry[frame]
                        VStack(spacing: 2) {
                            Text("Per month")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(total.currencyText(currencyCode))
                                .font(.headline)
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                        }
                        .frame(width: rect.width * 0.55)
                        .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
            .frame(height: height)
            .padding(.vertical, 6)

            ForEach(totals) { entry in
                HStack {
                    Circle()
                        .fill(entry.category.color)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(entry.category.title)
                    Spacer(minLength: 8)
                    Text(share(entry.amount, of: total), format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary)
                    Text(entry.amount.currencyText(currencyCode))
                        .font(.body.monospacedDigit())
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func share(_ value: Decimal, of total: Decimal) -> Double {
        total > 0 ? (value / total).doubleValue : 0
    }
}
