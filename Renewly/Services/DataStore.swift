import Foundation
import SwiftData

enum SettingsKeys {
    static let baseCurrency = "baseCurrency"
    static let notificationMinutes = "notificationMinutes"
    static let defaultNotificationMinutes = 9 * 60
}

/// All writes to the database go through here so every save reports its errors.
@MainActor
struct DataStore {
    let context: ModelContext
    let errors: ErrorCenter

    @discardableResult
    func save(_ action: String = String(localized: "Couldn't save changes.")) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            errors.report(error, while: action)
            return false
        }
    }

    func upsert(_ snapshot: SubscriptionSnapshot, includingStatus: Bool) {
        if let existing = item(id: snapshot.id) {
            existing.apply(snapshot, includingStatus: includingStatus)
        } else {
            context.insert(SubscriptionItem(snapshot: snapshot))
        }
    }

    func item(id: UUID) -> SubscriptionItem? {
        var descriptor = FetchDescriptor<SubscriptionItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    func setRate(_ rate: Decimal?, for code: String) {
        let descriptor = FetchDescriptor<CurrencyRate>(predicate: #Predicate { $0.currencyCode == code })
        let existing = (try? context.fetch(descriptor))?.first
        switch (existing, rate) {
        case let (row?, value?) where value > 0:
            row.rate = value
        case let (nil, value?) where value > 0:
            context.insert(CurrencyRate(currencyCode: code, rate: value))
        case let (row?, _):
            context.delete(row)
        default:
            break
        }
    }

    /// Makes the stored rates equal to `rates`, updating rows in place.
    func replaceRates(with rates: [String: Decimal]) throws {
        let existing = try context.fetch(FetchDescriptor<CurrencyRate>())
        var remaining = rates.filter { $0.value > 0 }
        for row in existing {
            if let value = remaining.removeValue(forKey: row.currencyCode) {
                row.rate = value
            } else {
                context.delete(row)
            }
        }
        for (code, value) in remaining {
            context.insert(CurrencyRate(currencyCode: code, rate: value))
        }
    }

    func delete(_ item: SubscriptionItem) {
        context.delete(item)
        save(String(localized: "Couldn't delete the subscription."))
    }

    @discardableResult
    func deleteAll() -> Bool {
        do {
            for item in try context.fetch(FetchDescriptor<SubscriptionItem>()) {
                context.delete(item)
            }
            try replaceRates(with: [:])
        } catch {
            context.rollback()
            errors.report(error, while: String(localized: "Couldn't delete the data."))
            return false
        }
        return save(String(localized: "Couldn't delete the data."))
    }

    /// Adds new subscriptions and updates ones with the same identifier, so re-importing never duplicates.
    @discardableResult
    func importData(_ data: ImportedData) -> Bool {
        do {
            try replaceRates(with: data.rates)
        } catch {
            context.rollback()
            errors.report(error, while: String(localized: "Couldn't import the file."))
            return false
        }
        for snapshot in data.subscriptions {
            upsert(snapshot, includingStatus: true)
        }
        return save(String(localized: "Couldn't import the file."))
    }

    /// Loads the sample subscriptions and prefills approximate rates for currencies without a rate.
    @discardableResult
    func loadDemo(converter: CurrencyConverter, now: Date) -> Bool {
        let demo = DemoData.subscriptions(now: now)
        for snapshot in demo {
            upsert(snapshot, includingStatus: true)
        }
        let rates = DemoData.suggestedRates(
            base: converter.baseCode,
            existing: converter.rates,
            codes: Set(demo.map(\.currencyCode))
        )
        for (code, rate) in rates {
            setRate(rate, for: code)
        }
        return save(String(localized: "Couldn't load the demo data."))
    }
}
