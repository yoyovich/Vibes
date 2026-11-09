import SwiftData
import SwiftUI

/// Add and edit form. `item == nil` creates a new subscription.
struct SubscriptionFormView: View {
    let item: SubscriptionItem?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Environment(NotificationService.self) private var notifications
    @State private var draft = SubscriptionDraft()
    @State private var touched: Set<DraftField> = []
    @State private var didLoad = false
    @AppStorage(SettingsKeys.baseCurrency) private var baseCurrency = CurrencyCatalog.defaultBase

    var body: some View {
        let fieldErrors = draft.errors()
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $draft.name, axis: .vertical)
                        .textInputAutocapitalization(.words)
                        .onChange(of: draft.name) { touched.insert(.name) }
                    FieldError(error: touched.contains(.name) ? fieldErrors[.name] : nil)
                    TextField("Amount", text: $draft.amountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: draft.amountText) { touched.insert(.amount) }
                    FieldError(error: touched.contains(.amount) ? fieldErrors[.amount] : nil)
                    Picker("Currency", selection: $draft.currencyCode) {
                        ForEach(CurrencyCatalog.codes, id: \.self) { code in
                            Text(CurrencyCatalog.displayName(for: code)).tag(code)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } header: {
                    Text("Subscription")
                }

                Section {
                    Picker("Billing period", selection: $draft.preset) {
                        ForEach(BillingPreset.allCases) { preset in
                            Text(preset.title).tag(preset)
                        }
                    }
                    if draft.preset == .custom {
                        Stepper(value: $draft.customCount, in: BillingPeriod.countRange) {
                            Text("Every: \(draft.customCount)")
                        }
                        Picker("Unit", selection: $draft.customUnit) {
                            ForEach(BillingUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                        Text(draft.period.title)
                            .foregroundStyle(.secondary)
                        FieldError(error: fieldErrors[.count])
                    }
                    DatePicker("First payment", selection: $draft.anchorDate, displayedComponents: .date)
                } header: {
                    Text("Billing")
                } footer: {
                    Text("Charges are always counted from the first payment date. If a month has no such day, the last day of the month is used.")
                }

                Section {
                    Toggle("Free trial", isOn: $draft.hasTrial.animation())
                        .onChange(of: draft.hasTrial) { suggestTrialEnd() }
                    if draft.hasTrial {
                        DatePicker("Trial ends", selection: $draft.trialEndDate, displayedComponents: .date)
                        FieldError(error: fieldErrors[.trial])
                    }
                } footer: {
                    if draft.hasTrial {
                        Text("No charges until the trial ends; the first charge is on its last day.")
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $draft.category) {
                        ForEach(SubscriptionCategory.allCases) { category in
                            Label { Text(category.title) } icon: { Image(systemName: category.symbolName) }
                                .tag(category)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section {
                    Picker("Reminder", selection: $draft.reminder) {
                        ForEach(ReminderOption.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    if draft.reminder != .off && !notifications.isAllowed {
                        NotificationPermissionHint()
                    }
                } header: {
                    Text("Reminder")
                }

                Section("Note") {
                    TextField("Note", text: $draft.note, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle(item == nil ? Text("New subscription") : Text("Edit subscription"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!fieldErrors.isEmpty)
                }
            }
            .onAppear(perform: load)
            .task { await notifications.refreshStatus() }
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let item {
            draft = SubscriptionDraft(snapshot: item.snapshot)
            touched = [.name, .amount]
        } else {
            draft.currencyCode = baseCurrency
        }
    }

    private func suggestTrialEnd() {
        let calendar = Calendar.current
        guard draft.hasTrial,
              calendar.startOfDay(for: draft.trialEndDate) <= calendar.startOfDay(for: draft.anchorDate),
              let suggested = calendar.date(byAdding: .day, value: 7, to: draft.anchorDate)
        else { return }
        draft.trialEndDate = suggested
    }

    private func save() {
        guard let snapshot = draft.snapshot() else {
            touched = [.name, .amount]
            return
        }
        let store = DataStore(context: context, errors: errors)
        store.upsert(snapshot, includingStatus: false)
        if store.save() {
            dismiss()
        }
    }
}

private struct FieldError: View {
    let error: DraftError?

    var body: some View {
        if let error {
            Label(error.message, systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityLabel(Text(error.message))
        }
    }
}

/// Explains that reminders need permission and links to the right place.
struct NotificationPermissionHint: View {
    @Environment(NotificationService.self) private var notifications
    @Environment(ErrorCenter.self) private var errors
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                notifications.isDenied
                    ? LocalizedStringKey("Notifications are turned off for Renewly. Reminders won't be shown.")
                    : LocalizedStringKey("Allow notifications to receive reminders."),
                systemImage: "bell.slash"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
            if notifications.isDenied {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
            } else {
                Button("Allow notifications") {
                    Task {
                        if let failure = await notifications.requestAuthorization() {
                            errors.report(failure)
                        }
                    }
                }
            }
        }
    }
}
