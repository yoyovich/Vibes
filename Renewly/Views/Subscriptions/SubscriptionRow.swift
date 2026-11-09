import SwiftUI

struct SubscriptionRow: View {
    let subscription: SubscriptionSnapshot
    let logic: LogicContext
    let now: Date

    var body: some View {
        let next = logic.schedule.nextCharge(of: subscription, now: now)
        let monthly = logic.analytics.monthlyInBase(subscription)
        let rateMissing = logic.converter.isRateMissing(for: subscription.currencyCode)
        HStack(alignment: .top, spacing: 12) {
            CategoryIcon(category: subscription.category)
            VStack(alignment: .leading, spacing: 3) {
                Text(subscription.name)
                    .font(.body.weight(.medium))
                    .lineLimit(3)
                Text(subscription.period.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let next {
                    Text("Next: \(next.dayText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No upcoming charges")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                SubscriptionBadges(subscription: subscription, now: now)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(subscription.amount.currencyText(subscription.currencyCode))
                    .font(.body.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                if subscription.currencyCode != logic.converter.baseCode {
                    Text("≈ \(monthly.currencyText(logic.converter.baseCode))/mo")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                if rateMissing {
                    RateMissingBadge()
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
