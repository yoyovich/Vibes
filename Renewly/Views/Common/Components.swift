import SwiftUI

struct CategoryIcon: View {
    let category: SubscriptionCategory
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 36

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.body.weight(.semibold))
            .foregroundStyle(category.color)
            .frame(width: size, height: size)
            .background(category.color.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Prominent marker shown wherever an amount was converted without a known rate.
struct RateMissingBadge: View {
    var body: some View {
        Label("Rate not set", systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .accessibilityLabel(Text("Exchange rate not set, converted at 1"))
    }
}

struct StatusBadge: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// Badges describing pause, cancellation and trial state.
struct SubscriptionBadges: View {
    let subscription: SubscriptionSnapshot
    let now: Date

    var body: some View {
        HStack(spacing: 4) {
            switch subscription.status {
            case .paused:
                StatusBadge(text: "Paused", color: .orange)
            case .cancelled:
                StatusBadge(text: "Cancelled", color: .red)
            case .active:
                EmptyView()
            }
            if let trialEnd = subscription.trialEndDate, trialEnd > now {
                StatusBadge(text: "Trial", color: .green)
            }
        }
    }
}

/// Value row that wraps instead of truncating at large Dynamic Type sizes.
struct ValueRow<Value: View>: View {
    let title: Text
    @ViewBuilder let value: Value

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline) {
                title
                Spacer(minLength: 12)
                value.multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                title
                value
            }
        }
        .accessibilityElement(children: .combine)
    }
}
