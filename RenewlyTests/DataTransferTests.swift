import SwiftData
import XCTest
@testable import Renewly

final class DataTransferTests: XCTestCase {
    private typealias D = TestCalendar
    private let transfer = DataTransfer(calendar: TestCalendar.utc)
    private let converter = CurrencyConverter(baseCode: "RUB", rates: ["USD": dec("92.5")])

    func testJSONRoundTripKeepsEverything() throws {
        let items = [
            makeSubscription(name: "Very long name, with \"quotes\"", amount: "9999999.99", anchor: D.date(2024, 2, 29), trialEnd: D.date(2024, 3, 10), reminder: .threeDays),
            makeSubscription(name: "Yen", amount: "2400", currency: "JPY", period: BillingPeriod(unit: .day, count: 10), anchor: D.date(2025, 1, 31), status: .cancelled, cancellation: D.date(2025, 6, 1))
        ]
        let data = try transfer.makeJSON(subscriptions: items, converter: converter, notificationMinutes: 600, now: D.date(2025, 1, 1))
        let imported = try transfer.decode(data)
        XCTAssertEqual(imported.subscriptions, items)
        XCTAssertEqual(imported.baseCurrency, "RUB")
        XCTAssertEqual(imported.rates, ["USD": dec("92.5")])
        XCTAssertEqual(imported.notificationMinutes, 600)
    }

    func testBrokenJSONIsRejectedWithReadableError() {
        XCTAssertThrowsError(try transfer.decode(Data("{ not json".utf8))) { error in
            XCTAssertEqual(error as? ImportError, .invalidFormat)
            XCTAssertFalse((error as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
        XCTAssertThrowsError(try transfer.decode(Data("{\"version\":1}".utf8))) { error in
            XCTAssertEqual(error as? ImportError, .invalidFormat)
        }
    }

    func testInvalidRecordAndNewerVersionAreRejected() throws {
        let item = makeSubscription(anchor: D.date(2025, 1, 1))
        let data = try transfer.makeJSON(subscriptions: [item], converter: converter, notificationMinutes: 540, now: .now)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        let negative = Data(json.replacingOccurrences(of: "\"amount\" : \"10\"", with: "\"amount\" : \"-10\"").utf8)
        XCTAssertThrowsError(try transfer.decode(negative)) { error in
            guard case .invalidRecord(let position, _) = error as? ImportError else { return XCTFail("Unexpected error \(error)") }
            XCTAssertEqual(position, 1)
        }
        let newer = Data(json.replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99").utf8)
        XCTAssertThrowsError(try transfer.decode(newer)) { error in
            XCTAssertEqual(error as? ImportError, .unsupportedVersion(99))
        }
    }

    func testCSVEscapesSpecialCharacters() {
        XCTAssertEqual(DataTransfer.csvField("plain"), "plain")
        XCTAssertEqual(DataTransfer.csvField("a,b"), "\"a,b\"")
        XCTAssertEqual(DataTransfer.csvField("say \"hi\""), "\"say \"\"hi\"\"\"")
        let csv = transfer.makeCSV(subscriptions: [makeSubscription(name: "x,y", anchor: D.date(2025, 1, 1))], converter: converter)
        let lines = csv.components(separatedBy: "\r\n")
        XCTAssertTrue(lines[0].hasPrefix("id,name,amount"))
        XCTAssertTrue(lines[1].contains("\"x,y\""))
    }
}

final class SubscriptionQueryTests: XCTestCase {
    private typealias D = TestCalendar
    private let analytics = SpendingAnalytics(schedule: TestCalendar.schedule, converter: CurrencyConverter(baseCode: "USD", rates: [:]))
    private lazy var items = [
        makeSubscription(name: "Gym", amount: "50", anchor: D.date(2025, 1, 20), category: .fitness),
        makeSubscription(name: "Netflix", amount: "15", anchor: D.date(2025, 1, 5), category: .streaming),
        makeSubscription(name: "Cloud", amount: "120", period: .yearly, anchor: D.date(2024, 3, 1), category: .cloud, status: .paused, pausedAt: D.date(2025, 1, 1))
    ]

    func testSortingByNextChargeNameAndCost() {
        var query = SubscriptionQuery()
        let now = D.date(2025, 2, 1)
        XCTAssertEqual(query.apply(to: items, analytics: analytics, now: now).map(\.name), ["Netflix", "Gym", "Cloud"])
        query.sort = .name
        XCTAssertEqual(query.apply(to: items, analytics: analytics, now: now).map(\.name), ["Cloud", "Gym", "Netflix"])
        query.sort = .monthlyCost
        XCTAssertEqual(query.apply(to: items, analytics: analytics, now: now).map(\.name), ["Gym", "Netflix", "Cloud"])
    }

    func testSearchAndFilters() {
        let now = D.date(2025, 2, 1)
        var query = SubscriptionQuery(searchText: "net")
        XCTAssertEqual(query.apply(to: items, analytics: analytics, now: now).map(\.name), ["Netflix"])
        query = SubscriptionQuery(status: .paused)
        XCTAssertEqual(query.apply(to: items, analytics: analytics, now: now).map(\.name), ["Cloud"])
        query = SubscriptionQuery(preset: .yearly)
        XCTAssertEqual(query.apply(to: items, analytics: analytics, now: now).map(\.name), ["Cloud"])
        query = SubscriptionQuery(searchText: "zzz")
        XCTAssertTrue(query.apply(to: items, analytics: analytics, now: now).isEmpty)
    }
}

final class PersistenceTests: XCTestCase {
    func testSubscriptionSurvivesSaveAndRefetchWithoutDuplicates() throws {
        let container = try ModelContainer(
            for: SubscriptionItem.self, CurrencyRate.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let snapshot = makeSubscription(name: "Saved", amount: "1234.56", currency: "EUR", anchor: TestCalendar.date(2025, 1, 31))
        context.insert(SubscriptionItem(snapshot: snapshot))
        try context.save()

        let fresh = ModelContext(container)
        let fetched = try fresh.fetch(FetchDescriptor<SubscriptionItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.snapshot, snapshot)

        fetched.first?.apply(makeSubscription(name: "Renamed", anchor: TestCalendar.date(2025, 1, 31)), includingStatus: false)
        try fresh.save()
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<SubscriptionItem>()).map(\.name), ["Renamed"])
    }

    func testDemoDataHasTwelveVariedSubscriptions() {
        let demo = DemoData.subscriptions(now: TestCalendar.date(2025, 6, 1), calendar: TestCalendar.utc)
        XCTAssertEqual(demo.count, 12)
        XCTAssertEqual(Set(demo.map(\.id)).count, 12)
        XCTAssertTrue(demo.contains { $0.trialEndDate != nil })
        XCTAssertTrue(demo.contains { $0.status == .paused })
        XCTAssertTrue(demo.contains { $0.status == .cancelled })
        XCTAssertTrue(demo.contains { TestCalendar.utc.component(.day, from: $0.anchorDate) == 31 })
        XCTAssertGreaterThanOrEqual(Set(demo.map(\.currencyCode)).count, 5)
        XCTAssertTrue(demo.allSatisfy { DraftValidationProbe.isValid($0) })
    }
}

private enum DraftValidationProbe {
    static func isValid(_ snapshot: SubscriptionSnapshot) -> Bool {
        var draft = SubscriptionDraft(snapshot: snapshot)
        draft.amountText = AmountParser.plainString(snapshot.amount)
        return draft.isValid(calendar: TestCalendar.utc)
    }
}
