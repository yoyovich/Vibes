import Foundation

/// File format written by "Export JSON" and accepted by "Import JSON".
struct ExportDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var baseCurrency: String
    var notificationMinutes: Int
    var rates: [String: String]
    var subscriptions: [SubscriptionRecord]
}

struct SubscriptionRecord: Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var amount: String
    var currency: String
    var periodUnit: String
    var periodCount: Int
    var anchorDate: String
    var category: String
    var note: String
    var trialEndDate: String?
    var reminderDays: Int
    var status: String
    var pausedAt: String?
    var cancellationDate: String?
}

enum ImportError: LocalizedError, Equatable {
    case unreadableFile
    case invalidFormat
    case unsupportedVersion(Int)
    case invalidRecord(position: Int, reason: String)
    case invalidSettings

    var errorDescription: String? { message }

    var message: String {
        switch self {
        case .unreadableFile:
            String(localized: "The file couldn't be read.")
        case .invalidFormat:
            String(localized: "The file isn't a Renewly export or is damaged.")
        case .unsupportedVersion(let version):
            String(localized: "This file was created by a newer version of Renewly (format \(version)).")
        case .invalidRecord(let position, let reason):
            String(localized: "Subscription #\(position) is invalid: \(reason)")
        case .invalidSettings:
            String(localized: "The file contains an unknown base currency or an invalid exchange rate.")
        }
    }
}

struct ImportedData: Equatable, Sendable {
    var baseCurrency: String
    var notificationMinutes: Int
    var rates: [String: Decimal]
    var subscriptions: [SubscriptionSnapshot]
}

/// JSON and CSV encoding of all user data. Date-only fields are written as `yyyy-MM-dd`
/// in the given calendar so they keep their day when imported in another time zone.
struct DataTransfer {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private static let posix = Locale(identifier: "en_US_POSIX")

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Self.posix
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func day(_ date: Date) -> String { dayFormatter.string(from: date) }

    private func parseDay(_ text: String) -> Date? {
        dayFormatter.date(from: text).map { calendar.startOfDay(for: $0) }
    }

    // MARK: Export

    func record(for item: SubscriptionSnapshot) -> SubscriptionRecord {
        SubscriptionRecord(
            id: item.id,
            name: item.name,
            amount: AmountParser.plainString(item.amount),
            currency: item.currencyCode,
            periodUnit: item.period.unit.rawValue,
            periodCount: item.period.count,
            anchorDate: day(item.anchorDate),
            category: item.category.rawValue,
            note: item.note,
            trialEndDate: item.trialEndDate.map { day($0) },
            reminderDays: item.reminder.rawValue,
            status: item.status.rawValue,
            pausedAt: item.pausedAt.map { day($0) },
            cancellationDate: item.cancellationDate.map { day($0) }
        )
    }

    func makeJSON(subscriptions: [SubscriptionSnapshot], converter: CurrencyConverter, notificationMinutes: Int, now: Date) throws -> Data {
        let document = ExportDocument(
            version: ExportDocument.currentVersion,
            exportedAt: now,
            baseCurrency: converter.baseCode,
            notificationMinutes: notificationMinutes,
            rates: converter.rates.filter { $0.value > 0 }.mapValues(AmountParser.plainString),
            subscriptions: subscriptions.map { record(for: $0) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    func makeCSV(subscriptions: [SubscriptionSnapshot], converter: CurrencyConverter) -> String {
        let header = [
            "id", "name", "amount", "currency", "period_unit", "period_count", "anchor_date",
            "category", "status", "trial_end_date", "cancellation_date", "reminder_days",
            "monthly_cost_base", "base_currency", "note"
        ]
        let rows = subscriptions.map { item -> [String] in
            let row = record(for: item)
            let monthly = converter.convert(BillingSchedule.monthlyCost(of: item), from: item.currencyCode).rounded(scale: 2)
            return [
                row.id.uuidString, row.name, row.amount, row.currency, row.periodUnit,
                String(row.periodCount), row.anchorDate, row.category, row.status,
                row.trialEndDate ?? "", row.cancellationDate ?? "",
                item.reminder.daysBefore.map { String($0) } ?? "",
                AmountParser.plainString(monthly), converter.baseCode, row.note
            ]
        }
        return ([header] + rows)
            .map { $0.map(Self.csvField).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    static func csvField(_ value: String) -> String {
        let special: Set<Character> = [",", "\"", "\n", "\r", "\r\n"]
        guard value.contains(where: { special.contains($0) }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Import

    func decode(_ data: Data) throws -> ImportedData {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: ExportDocument
        do {
            document = try decoder.decode(ExportDocument.self, from: data)
        } catch {
            throw ImportError.invalidFormat
        }
        guard document.version <= ExportDocument.currentVersion else {
            throw ImportError.unsupportedVersion(document.version)
        }
        guard document.version >= 1 else { throw ImportError.invalidFormat }
        guard CurrencyCatalog.codes.contains(document.baseCurrency) else { throw ImportError.invalidSettings }

        var rates: [String: Decimal] = [:]
        for (code, text) in document.rates {
            guard CurrencyCatalog.codes.contains(code), let value = AmountParser.parse(text), value > 0 else {
                throw ImportError.invalidSettings
            }
            rates[code] = value
        }

        var seen = Set<UUID>()
        var subscriptions: [SubscriptionSnapshot] = []
        for (index, record) in document.subscriptions.enumerated() {
            let item = try snapshot(from: record, position: index + 1)
            if seen.insert(item.id).inserted { subscriptions.append(item) }
        }
        let minutes = (0..<(24 * 60)).contains(document.notificationMinutes) ? document.notificationMinutes : 9 * 60
        return ImportedData(baseCurrency: document.baseCurrency, notificationMinutes: minutes, rates: rates, subscriptions: subscriptions)
    }

    private func snapshot(from record: SubscriptionRecord, position: Int) throws -> SubscriptionSnapshot {
        func fail(_ reason: String) -> ImportError { .invalidRecord(position: position, reason: reason) }

        let name = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw fail(String(localized: "the name is empty.")) }
        guard let amount = AmountParser.parse(record.amount), amount > 0, amount <= AmountParser.maximum else {
            throw fail(String(localized: "the amount must be greater than zero."))
        }
        guard CurrencyCatalog.codes.contains(record.currency) else {
            throw fail(String(localized: "unknown currency."))
        }
        guard let unit = BillingUnit(rawValue: record.periodUnit), BillingPeriod.countRange.contains(record.periodCount) else {
            throw fail(String(localized: "invalid billing period."))
        }
        guard let anchor = parseDay(record.anchorDate) else { throw fail(String(localized: "invalid date.")) }
        let optionalDays = [record.trialEndDate, record.pausedAt, record.cancellationDate]
        let parsedDays = optionalDays.map { text in text.flatMap { parseDay($0) } }
        guard zip(optionalDays, parsedDays).allSatisfy({ $0 == nil || $1 != nil }) else {
            throw fail(String(localized: "invalid date."))
        }
        guard let status = SubscriptionStatus(rawValue: record.status),
              let category = SubscriptionCategory(rawValue: record.category),
              let reminder = ReminderOption(rawValue: record.reminderDays)
        else { throw fail(String(localized: "unknown status, category or reminder.")) }

        return SubscriptionSnapshot(
            id: record.id,
            name: name,
            amount: amount,
            currencyCode: record.currency,
            period: BillingPeriod(unit: unit, count: record.periodCount),
            anchorDate: anchor,
            category: category,
            note: record.note,
            trialEndDate: parsedDays[0],
            reminder: reminder,
            status: status,
            pausedAt: status == .paused ? (parsedDays[1] ?? anchor) : nil,
            cancellationDate: status == .cancelled ? (parsedDays[2] ?? anchor) : nil
        )
    }
}
