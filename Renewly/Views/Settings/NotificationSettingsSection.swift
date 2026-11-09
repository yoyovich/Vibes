import SwiftUI

struct NotificationSettingsSection: View {
    @Binding var minutes: Int
    @Environment(NotificationService.self) private var notifications
    @Environment(\.scenePhase) private var scenePhase

    private var time: Binding<Date> {
        Binding {
            let calendar = Calendar.current
            return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            minutes = (parts.hour ?? 9) * 60 + (parts.minute ?? 0)
        }
    }

    var body: some View {
        Section {
            DatePicker("Reminder time", selection: time, displayedComponents: .hourAndMinute)
            ValueRow(title: Text("Permission")) {
                Text(statusText)
                    .foregroundStyle(notifications.isAllowed ? Color.secondary : Color.orange)
            }
            if notifications.isAllowed {
                ValueRow(title: Text("Scheduled reminders")) {
                    Text(notifications.scheduledCount, format: .number)
                        .foregroundStyle(.secondary)
                }
                if notifications.failedCount > 0 {
                    Text("Some reminders couldn't be scheduled: \(notifications.failedCount)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else {
                NotificationPermissionHint()
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Up to 64 nearest reminders are scheduled; the list is refreshed whenever data changes or the app opens.")
        }
        .task(id: scenePhase) { await notifications.refreshStatus() }
    }

    private var statusText: LocalizedStringKey {
        switch notifications.status {
        case .authorized, .provisional, .ephemeral: "Allowed"
        case .denied: "Denied"
        default: "Not requested"
        }
    }
}
