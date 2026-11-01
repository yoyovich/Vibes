import Foundation
import Combine

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var items: [MusicItem] = []
    private let storageKey = "vibes.saved_items.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([MusicItem].self, from: data) {
            items = decoded
        }
    }

    @discardableResult
    func add(_ item: MusicItem) -> Bool {
        guard !items.contains(where: { $0.url == item.url }) else { return false }
        items.insert(item, at: 0)
        persist()
        return true
    }

    func remove(_ item: MusicItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
