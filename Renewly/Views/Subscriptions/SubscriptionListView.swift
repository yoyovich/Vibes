import SwiftData
import SwiftUI

struct SubscriptionListView: View {
    @Environment(\.modelContext) private var context
    @Environment(ErrorCenter.self) private var errors
    @Environment(\.currencyConverter) private var converter
    @Query private var items: [SubscriptionItem]
    @State private var query = SubscriptionQuery()
    @State private var isAdding = false
    @State private var editing: SubscriptionItem?
    @State private var pendingDeletion: SubscriptionItem?

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    NoSubscriptionsView(onAdd: { isAdding = true })
                } else {
                    list
                }
            }
            .navigationTitle("Subscriptions")
            .searchable(text: $query.searchText, prompt: Text("Search by name"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SubscriptionFilterMenu(query: $query)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("Add subscription", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: SubscriptionItem.self) { item in
                SubscriptionDetailView(item: item)
            }
            .sheet(isPresented: $isAdding) {
                SubscriptionFormView(item: nil)
            }
            .sheet(item: $editing) { item in
                SubscriptionFormView(item: item)
            }
            .confirmationDialog(
                "Delete subscription?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { item in
                Button("Delete", role: .destructive) {
                    DataStore(context: context, errors: errors).delete(item)
                    pendingDeletion = nil
                }
            } message: { item in
                Text("“\(item.name)” and its history will be removed.")
            }
        }
    }

    private var list: some View {
        let now = Date.now
        let logic = LogicContext(converter: converter)
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let results = query.apply(to: items.map(\.snapshot), analytics: logic.analytics, now: now)
        return List {
            if results.isEmpty {
                ContentUnavailableView {
                    Label("Nothing found", systemImage: "magnifyingglass")
                } description: {
                    Text("No subscriptions match your search or filters.")
                } actions: {
                    Button("Reset filters") { query = SubscriptionQuery(sort: query.sort) }
                }
                .listRowBackground(Color.clear)
            }
            ForEach(results) { snapshot in
                if let item = byID[snapshot.id] {
                    NavigationLink(value: item) {
                        SubscriptionRow(subscription: snapshot, logic: logic, now: now)
                    }
                    .swipeActions(edge: .leading) {
                        pauseButton(for: item)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            pendingDeletion = item
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                        Button {
                            editing = item
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pauseButton(for item: SubscriptionItem) -> some View {
        if item.status == .active {
            Button {
                item.pause(at: .now)
                DataStore(context: context, errors: errors).save()
            } label: {
                Label("Pause", systemImage: "pause.circle")
            }
            .tint(.orange)
        } else {
            Button {
                item.resume()
                DataStore(context: context, errors: errors).save()
            } label: {
                Label("Resume", systemImage: "play.circle")
            }
            .tint(.green)
        }
    }
}

private struct SubscriptionFilterMenu: View {
    @Binding var query: SubscriptionQuery

    var body: some View {
        Menu {
            Picker(selection: $query.sort) {
                ForEach(SubscriptionSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            } label: {
                Label("Sort by", systemImage: "arrow.up.arrow.down")
            }
            .pickerStyle(.menu)
            Picker(selection: $query.status) {
                Text("All statuses").tag(SubscriptionStatus?.none)
                ForEach(SubscriptionStatus.allCases) { status in
                    Text(status.title).tag(SubscriptionStatus?.some(status))
                }
            } label: {
                Label("Status", systemImage: "circle.lefthalf.filled")
            }
            .pickerStyle(.menu)
            Picker(selection: $query.category) {
                Text("All categories").tag(SubscriptionCategory?.none)
                ForEach(SubscriptionCategory.allCases) { category in
                    Label { Text(category.title) } icon: { Image(systemName: category.symbolName) }
                        .tag(SubscriptionCategory?.some(category))
                }
            } label: {
                Label("Category", systemImage: "square.grid.2x2")
            }
            .pickerStyle(.menu)
            Picker(selection: $query.preset) {
                Text("All periods").tag(BillingPreset?.none)
                ForEach(BillingPreset.allCases) { preset in
                    Text(preset.title).tag(BillingPreset?.some(preset))
                }
            } label: {
                Label("Billing period", systemImage: "calendar")
            }
            .pickerStyle(.menu)
        } label: {
            Label("Filter and sort", systemImage: query.hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
        }
        .accessibilityValue(query.hasActiveFilters ? Text("Filters applied") : Text("No filters"))
    }
}
