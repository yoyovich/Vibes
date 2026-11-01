import XCTest

/// Network integration test. No fake engine, WebKit preference hacks or taps
/// inside the iframe: exactly one native library-row tap must produce PLAY
/// and advancing official Widget API progress.
final class OneTapPlaybackTests: XCTestCase {
    @MainActor
    func testPublicSoundCloudTrackStartsWithOneLibraryTap() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--soundcloud-smoke"]
        app.launch()
        let library = app.tabBars.buttons["Медиатека"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.tap()
        let row = app.buttons["library-track-5CE96F2B-43AA-44EA-8B9A-ECE76BA055E6"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap() // The only playback-start tap in this test.
        let state = app.staticTexts["playback-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 10))
        let advancing = NSPredicate { _, _ in
            let parts = (state.value as? String ?? "").split(separator: "|")
            return parts.count == 2 && parts[0] == "playing" && (Double(parts[1]) ?? 0) >= 2
        }
        let started = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: advancing, object: state)], timeout: 45)
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = "one-native-tap-official-widget-result"; evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(started, .completed,
            "One-tap playback NOT confirmed. State: \(state.value ?? "missing"). Error: \(app.staticTexts["playback-error"].label)")
        guard started == .completed else { return }
        print("LIVE_WIDGET_PLAY_AND_PROGRESS_CONFIRMED: \(state.value ?? "missing")")

        app.tabBars.buttons["Поиск"].tap()
        XCTAssertTrue(state.exists, "Playback dock must remain outside the tab content")
        app.buttons["playback-toggle"].tap()
        let paused = NSPredicate { _, _ in (state.value as? String ?? "").hasPrefix("paused|") }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: paused, object: state)], timeout: 10), .completed)
    }
}
