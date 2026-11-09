import SwiftData
import SwiftUI

@main
struct RenewlyApp: App {
    private let container: Result<ModelContainer, Error>
    @State private var notifications = NotificationService()
    @State private var errors = ErrorCenter()

    init() {
        do {
            container = .success(try ModelContainer(for: SubscriptionItem.self, CurrencyRate.self))
        } catch {
            container = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let modelContainer):
                RootView()
                    .modelContainer(modelContainer)
                    .environment(notifications)
                    .environment(errors)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Couldn't open the database", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(error.localizedDescription)
                }
            }
        }
    }
}
