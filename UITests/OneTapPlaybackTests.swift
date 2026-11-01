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
        XCTAssertFalse(app.webViews["soundcloud-widget"].exists, "Idle web engine must not occupy the hit-test tree")
        library.tap()
        let row = app.descendants(matching: .any).matching(identifier: "library-track-5CE96F2B-43AA-44EA-8B9A-ECE76BA055E6").firstMatch
        guard row.waitForExistence(timeout: 10) else {
            let evidence = XCTAttachment(screenshot: app.screenshot())
            evidence.lifetime = .keepAlways; add(evidence)
            print(app.debugDescription)
            XCTFail("Library tab did not expose its saved track; see hierarchy")
            return
        }
        row.tap() // The only playback-start tap in this test.
        let state = app.descendants(matching: .any).matching(identifier: "playback-state").firstMatch
        guard state.waitForExistence(timeout: 10) else {
            let evidence = XCTAttachment(screenshot: app.screenshot())
            evidence.lifetime = .keepAlways; add(evidence)
            print(app.debugDescription)
            XCTFail("Library tap did not expose playback state. See screenshot/accessibility hierarchy.")
            return
        }
        let advancing = NSPredicate { _, _ in
            let parts = (state.value as? String ?? "").split(separator: "|")
            return parts.count == 2 && parts[0] == "playing" && (Double(parts[1]) ?? 0) >= 2
        }
        let started = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: advancing, object: state)], timeout: 45)
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = "one-native-tap-official-widget-result"; evidence.lifetime = .keepAlways
        add(evidence)
        XCTAssertEqual(started, .completed,
            "One-tap playback NOT confirmed. State: \(state.value ?? "missing"). Error: \(app.staticTexts["playback-error"].exists ? app.staticTexts["playback-error"].label : "none")")
        guard started == .completed else { return }
        print("LIVE_WIDGET_PLAY_AND_PROGRESS_CONFIRMED: \(state.value ?? "missing")")

        app.tabBars.buttons["Поиск"].tap()
        XCTAssertTrue(state.exists, "Playback dock must remain outside the tab content")
        app.buttons["playback-toggle"].tap()
        let paused = NSPredicate { _, _ in (state.value as? String ?? "").hasPrefix("paused|") }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: paused, object: state)], timeout: 10), .completed)
    }
}
