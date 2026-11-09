import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case overview
    case subscriptions
    case statistics
    case settings
}

/// Hosts the tabs, shares the currency converter and keeps reminders in sync with the data.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NotificationService.self) private var notifications
    @Environment(ErrorCenter.self) private var errors
    @Query private var items: [SubscriptionItem]
    @Query private var rates: [CurrencyRate]
    @AppStorage(SettingsKeys.baseCurrency) private var baseCurrency = CurrencyCatalog.defaultBase
    @AppStorage(SettingsKeys.notificationMinutes) private var notificationMinutes = SettingsKeys.defaultNotificationMinutes
    @State private var selectedTab: AppTab = .overview

    private var converter: CurrencyConverter {
        CurrencyConverter(
            baseCode: baseCurrency,
            rates: Dictionary(rates.map { ($0.currencyCode, $0.rate) }, uniquingKeysWith: { first, _ in first })
        )
    }

    private struct ScheduleKey: Equatable {
        let snapshots: [SubscriptionSnapshot]
        let minutes: Int
        let isActive: Bool
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(selectedTab: $selectedTab)
                .tabItem { Label("Overview", systemImage: "chart.pie") }
                .tag(AppTab.overview)
            SubscriptionListView()
                .tabItem { Label("Subscriptions", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.subscriptions)
            StatisticsView()
                .tabItem { Label("Statistics", systemImage: "chart.bar.xaxis") }
                .tag(AppTab.statistics)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .environment(\.currencyConverter, converter)
        .task(id: ScheduleKey(snapshots: items.map(\.snapshot), minutes: notificationMinutes, isActive: scenePhase == .active)) {
            guard scenePhase == .active else { return }
            let plans = ReminderPlanner.plan(
                items.map(\.snapshot),
                now: .now,
                minutesAfterMidnight: notificationMinutes,
                schedule: BillingSchedule()
            )
            await notifications.reschedule(plans)
        }
        .alert(
            "Something went wrong",
            isPresented: Binding(get: { errors.message != nil }, set: { if !$0 { errors.message = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errors.message ?? "")
        }
    }
}
