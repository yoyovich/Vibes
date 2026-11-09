import Foundation
import Observation
import UserNotifications

/// Owns the local notification schedule. Only local notifications are used.
@MainActor
@Observable
final class NotificationService {
    private(set) var status: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0
    private(set) var failedCount = 0

    private let center = UNUserNotificationCenter.current()

    var isAllowed: Bool {
        switch status {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }

    var isDenied: Bool { status == .denied }

    func refreshStatus() async {
        status = await center.notificationSettings().authorizationStatus
    }

    /// Returns a user-facing error message if the system refused the request.
    func requestAuthorization() async -> String? {
        var failure: String?
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            failure = error.localizedDescription
        }
        await refreshStatus()
        return failure
    }

    /// Replaces every pending reminder with the given plan.
    func reschedule(_ plans: [ReminderPlan], calendar: Calendar = .current) async {
        await refreshStatus()
        center.removeAllPendingNotificationRequests()
        guard isAllowed else {
            scheduledCount = 0
            failedCount = 0
            return
        }
        var scheduled = 0
        var failed = 0
        for plan in plans.prefix(ReminderPlanner.systemLimit) {
            let content = UNMutableNotificationContent()
            content.title = plan.name
            content.body = Self.body(for: plan)
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
                scheduled += 1
            } catch {
                failed += 1
            }
        }
        scheduledCount = scheduled
        failedCount = failed
    }

    static func body(for plan: ReminderPlan) -> String {
        let price = plan.amount.formatted(.currency(code: plan.currencyCode))
        switch plan.daysBefore {
        case 0:
            return String(localized: "\(price) will be charged today.")
        default:
            let date = plan.chargeDate.formatted(date: .long, time: .omitted)
            return String(localized: "\(price) will be charged on \(date).")
        }
    }
}
