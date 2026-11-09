import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Environment(NotificationService.self) private var notifications
    @Environment(\.currencyConverter) private var converter
    @Query private var items: [SubscriptionItem]
    @AppStorage(SettingsKeys.baseCurrency) private var baseCurrency = CurrencyCatalog.defaultBase
    @AppStorage(SettingsKeys.notificationMinutes) private var notificationMinutes = SettingsKeys.defaultNotificationMinutes
    @State private var exportFile: ExportFile?
    @State private var isImporting = false
    @State private var isConfirmingDeleteAll = false
    @State private var infoMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                currencySection
                NotificationSettingsSection(minutes: $notificationMinutes)
                dataSection
                Section {
                    ValueRow(title: Text("Version")) {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Renewly works fully offline. Your data never leaves this device unless you export it.")
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $exportFile) { file in
                ActivityView(items: [file.url])
                    .ignoresSafeArea()
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Delete all data?", isPresented: $isConfirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete all data", role: .destructive) {
                    DataStore(context: context, errors: errors).deleteAll()
                }
            } message: {
                Text("All subscriptions and exchange rates will be permanently removed.")
            }
            .alert(
                "Done",
                isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(infoMessage ?? "")
            }
        }
    }

    private var usedCurrencies: [String] {
        Array(Set(items.map(\.currencyCode))).filter { $0 != baseCurrency }.sorted()
    }

    private var currencySection: some View {
        Section {
            Picker("Base currency", selection: Binding(get: { baseCurrency }, set: changeBaseCurrency)) {
                ForEach(CurrencyCatalog.codes, id: \.self) { code in
                    Text(CurrencyCatalog.displayName(for: code)).tag(code)
                }
            }
            .pickerStyle(.navigationLink)
            NavigationLink {
                RatesView(codes: usedCurrencies)
            } label: {
                HStack {
                    Text("Exchange rates")
                    Spacer()
                    if usedCurrencies.contains(where: { converter.isRateMissing(for: $0) }) {
                        RateMissingBadge()
                    }
                }
            }
        } header: {
            Text("Currency")
        } footer: {
            Text("All totals are shown in the base currency. When you change it, rates are recalculated where possible.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            Button {
                export(json: true)
            } label: {
                Label("Export JSON", systemImage: "square.and.arrow.up")
            }
            Button {
                export(json: false)
            } label: {
                Label("Export CSV", systemImage: "tablecells")
            }
            Button {
                isImporting = true
            } label: {
                Label("Import JSON", systemImage: "square.and.arrow.down")
            }
            Button {
                if DataStore(context: context, errors: errors).loadDemo(converter: converter, now: .now) {
                    infoMessage = String(localized: "Demo data loaded.")
                }
            } label: {
                Label("Load demo data", systemImage: "wand.and.stars")
            }
            Button(role: .destructive) {
                isConfirmingDeleteAll = true
            } label: {
                Label("Delete all data", systemImage: "trash")
            }
        }
    }

    private func changeBaseCurrency(_ newBase: String) {
        guard newBase != baseCurrency else { return }
        let store = DataStore(context: context, errors: errors)
        do {
            try store.replaceRates(with: converter.rebased(to: newBase))
        } catch {
            context.rollback()
            errors.report(error, while: String(localized: "Couldn't update exchange rates."))
            return
        }
        if store.save(String(localized: "Couldn't update exchange rates.")) {
            baseCurrency = newBase
        }
    }

    private func export(json: Bool) {
        let transfer = DataTransfer()
        let snapshots = items.map(\.snapshot).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Renewly-\(stamp)")
            .appendingPathExtension(json ? "json" : "csv")
        do {
            let data: Data
            if json {
                data = try transfer.makeJSON(subscriptions: snapshots, converter: converter, notificationMinutes: notificationMinutes, now: .now)
            } else {
                data = Data(transfer.makeCSV(subscriptions: snapshots, converter: converter).utf8)
            }
            try data.write(to: url, options: .atomic)
            exportFile = ExportFile(url: url)
        } catch {
            errors.report(error, while: String(localized: "Couldn't export the data."))
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw ImportError.unreadableFile
            }
            let imported = try DataTransfer().decode(data)
            if DataStore(context: context, errors: errors).importData(imported) {
                baseCurrency = imported.baseCurrency
                notificationMinutes = imported.notificationMinutes
                infoMessage = String(localized: "Imported subscriptions: \(imported.subscriptions.count)")
            }
        } catch {
            errors.report(error, while: String(localized: "Couldn't import the file."))
        }
    }
}

struct ExportFile: Identifiable {
    let url: URL
    var id: URL { url }
}
