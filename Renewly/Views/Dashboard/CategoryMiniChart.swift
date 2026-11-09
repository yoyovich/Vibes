import Charts
import SwiftUI

struct CategoryMiniChart: View {
    let totals: [CategoryAmount]
    let currencyCode: String
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 28

    var body: some View {
        if totals.isEmpty {
            ContentUnavailableView(
                "No active spending",
                systemImage: "chart.bar",
                description: Text("Active subscriptions will appear here.")
            )
        } else {
            Chart(totals) { entry in
                BarMark(
                    x: .value("Per month", entry.amount.doubleValue),
                    y: .value("Category", entry.category.localizedTitle)
                )
                .foregroundStyle(entry.category.color)
                .annotation(position: .trailing, alignment: .leading) {
                    Text(entry.amount.currencyText(currencyCode))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text(entry.category.localizedTitle))
                .accessibilityValue(Text(entry.amount.currencyText(currencyCode)))
            }
            .chartXAxis(.hidden)
            .chartXScale(range: .plotDimension(endPadding: 90))
            .frame(height: CGFloat(totals.count) * rowHeight + 16)
            .padding(.vertical, 4)
        }
    }
}
