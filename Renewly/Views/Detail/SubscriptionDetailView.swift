import SwiftData
import SwiftUI

struct SubscriptionDetailView: View {
    let item: SubscriptionItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Environment(\.currencyConverter) private var converter
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var isCancelling = false

    var body: some View {
        if item.isDeleted || item.modelContext == nil {
            ContentUnavailableView("Subscription deleted", systemImage: "trash")
        } else {
            details
        }
    }

    private var store: DataStore { DataStore(context: context, errors: errors) }

    private var details: some View {
        let now = Date.now
        let subscription = item.snapshot
        let logic = LogicContext(converter: converter)
        let schedule = logic.schedule
        let base = converter.baseCode
        let monthly = logic.analytics.monthlyInBase(subscription)
        let nextCharges = schedule.upcomingCharges(of: subscription, now: now, count: 6)
        let spent = schedule.totalSpent(of: subscription, now: now)
        let rateMissing = converter.isRateMissing(for: subscription.currencyCode)

        return List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    CategoryIcon(category: subscription.category)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(subscription.name)
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subscription.category.title)
                            .foregroundStyle(.secondary)
                        SubscriptionBadges(subscription: subscription, now: now)
                    }
                }
                .accessibilityElement(children: .combine)
                statusDescription(subscription, schedule: schedule, now: now)
            }

            Section("Cost") {
                ValueRow(title: Text("Price")) {
                    Text("\(subscription.amount.currencyText(subscription.currencyCode)) · \(subscription.period.title)")
                }
                ValueRow(title: Text("Per month")) { Text(monthly.currencyText(base)) }
                ValueRow(title: Text("Per year")) { Text((monthly * 12).currencyText(base)) }
                if rateMissing {
                    RateMissingBadge()
                }
            }

            Section("Next charges") {
                if nextCharges.isEmpty {
                    Text("No upcoming charges")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nextCharges, id: \.self) { date in
                        ValueRow(title: Text(date.dayText)) {
                            DaysLeftText(days: schedule.daysUntil(date, now: now))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section {
                ValueRow(title: Text("Spent since \(subscription.anchorDate.dayText)")) {
                    Text(spent.currencyText(subscription.currencyCode))
                }
                if subscription.currencyCode != base {
                    ValueRow(title: Text("In base currency")) {
                        Text(converter.convert(spent, from: subscription.currencyCode).currencyText(base))
                    }
                }
            } footer: {
                Text("Counted from charges that have already happened.")
            }

            if !subscription.note.isEmpty {
                Section("Note") {
                    Text(subscription.note)
                }
            }

            Section("Actions") {
                actionButtons(subscription)
            }
        }
        .navigationTitle(subscription.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Edit") { isEditing = true }
        }
        .sheet(isPresented: $isEditing) {
            SubscriptionFormView(item: item)
        }
        .sheet(isPresented: $isCancelling) {
            CancelSubscriptionSheet { date in
                item.cancel(on: date)
                store.save()
            }
        }
        .confirmationDialog("Delete subscription?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                dismiss()
                store.delete(item)
            }
        } message: {
            Text("“\(subscription.name)” and its history will be removed.")
        }
    }

    @ViewBuilder
    private func statusDescription(_ subscription: SubscriptionSnapshot, schedule: BillingSchedule, now: Date) -> some View {
        switch subscription.status {
        case .paused:
            Text("Paused. Not included in totals or reminders.")
                .foregroundStyle(.secondary)
        case .cancelled:
            if let date = subscription.cancellationDate {
                if schedule.isInEffect(subscription, now: now) {
                    Text("Cancelled, active until \(date.dayText).")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Cancelled on \(date.dayText).")
                        .foregroundStyle(.secondary)
                }
            }
        case .active:
            if let next = schedule.nextCharge(of: subscription, now: now) {
                ValueRow(title: Text("Next charge")) {
                    VStack(alignment: .trailing) {
                        Text(next.dayText)
                        DaysLeftText(days: schedule.daysUntil(next, now: now))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionButtons(_ subscription: SubscriptionSnapshot) -> some View {
        switch subscription.status {
        case .active:
            Button {
                item.pause(at: .now)
                store.save()
            } label: {
                Label("Pause", systemImage: "pause.circle")
            }
            Button {
                isCancelling = true
            } label: {
                Label("Cancel subscription", systemImage: "xmark.circle")
            }
        case .paused, .cancelled:
            Button {
                item.resume()
                store.save()
            } label: {
                Label("Resume", systemImage: "play.circle")
            }
        }
        Button {
            isEditing = true
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

private struct CancelSubscriptionSheet: View {
    let onConfirm: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Cancellation date", selection: $date, displayedComponents: .date)
                Text("The subscription stays active until this date and is excluded afterwards. Its history is kept.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Cancel subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onConfirm(Calendar.current.startOfDay(for: date))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
