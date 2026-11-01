import Foundation

@MainActor
private final class FakeEngine: PlaybackEngine {
    var onEvent: ((UUID, PlaybackEvent) -> Void)?
    var loads: [(MusicItem, UUID)] = []
    var pauses: [UUID] = []
    var resumes: [UUID] = []
    var stops = 0
    var onLoad: ((UUID) -> Void)?
    func load(_ item: MusicItem, requestID: UUID) { loads.append((item, requestID)); onLoad?(requestID) }
    func resume(requestID: UUID) { resumes.append(requestID) }
    func pause(requestID: UUID) { pauses.append(requestID) }
    func stop() { stops += 1 }
    func emit(_ event: PlaybackEvent, _ id: UUID) { onEvent?(id, event) }
}

@MainActor
private final class ManualScheduler: PlaybackScheduler {
    final class Ticket: PlaybackCancellation {
        let seconds: Double
        let action: @MainActor () -> Void
        var cancelled = false
        init(_ seconds: Double, _ action: @escaping @MainActor () -> Void) { self.seconds = seconds; self.action = action }
        func cancel() { cancelled = true }
    }
    var tickets: [Ticket] = []
    func schedule(after seconds: Double, action: @escaping @MainActor () -> Void) -> any PlaybackCancellation {
        let ticket = Ticket(seconds, action); tickets.append(ticket); return ticket
    }
    var latest: Ticket { tickets.last! }
}

@main
struct PlaybackCoordinatorTests {
    @MainActor static func main() throws {
        var passed = 0
        func test(_ name: String, _ body: () throws -> Void) rethrows {
            try body(); passed += 1; print("PASS \(name)")
        }
        func item(_ name: String = "a", source: MusicSource = .soundCloud) -> MusicItem {
            MusicItem(source: source, url: source == .soundCloud ? "https://soundcloud.com/test/\(name)" : "https://open.spotify.com/track/123",
                      title: name, artworkURL: nil)
        }
        func rig() -> (PlaybackCoordinator, FakeEngine, ManualScheduler) {
            let engine = FakeEngine(); let scheduler = ManualScheduler()
            return (PlaybackCoordinator(engine: engine, scheduler: scheduler), engine, scheduler)
        }

        test("initial state and single tap do not fabricate PLAY") {
            let (c, engine, scheduler) = rig()
            assert(c.snapshot.phase == .idle && c.snapshot.item == nil)
            c.select(item())
            assert(c.snapshot.phase == .loading && !c.snapshot.confirmedPlayback)
            assert(engine.loads.count == 1 && scheduler.latest.seconds == 30)
            engine.emit(.ready, c.requestID!)
            assert(c.snapshot.phase == .loading)
            engine.emit(.playing, c.requestID!)
            assert(c.snapshot.phase == .playing && c.snapshot.confirmedPlayback)
        }
        test("pause and resume await engine acknowledgements") {
            let (c, engine, _) = rig(); c.select(item()); let id = c.requestID!
            engine.emit(.playing, id); c.pause()
            assert(c.snapshot.phase == .loading && engine.pauses == [id])
            engine.emit(.paused, id); assert(c.snapshot.phase == .paused)
            c.resume(); assert(c.snapshot.phase == .loading && engine.resumes == [id])
            engine.emit(.playing, id); assert(c.snapshot.phase == .playing)
            assert(engine.loads.count == 1)
        }
        test("rapid track switches cancel deadlines and reject stale events") {
            let (c, engine, scheduler) = rig(); c.select(item("a"))
            let oldID = c.requestID!; let oldDeadline = scheduler.latest
            c.select(item("b")); let newID = c.requestID!
            assert(oldID != newID && oldDeadline.cancelled && engine.stops == 2)
            engine.emit(.playing, oldID); engine.emit(.failed(.widget), oldID)
            oldDeadline.action() // Simulate a cancelled callback already enqueued.
            assert(c.snapshot.item?.title == "b" && c.snapshot.phase == .loading)
            engine.emit(.playing, newID); assert(c.snapshot.phase == .playing)
        }
        test("1000 rapid switches cannot resurrect old tracks") {
            let (c, engine, scheduler) = rig()
            for index in 0..<1000 {
                let old = c.requestID; c.select(item("\(index)"))
                if let old { engine.emit(.playing, old); engine.emit(.finished, old) }
            }
            for ticket in scheduler.tickets.dropLast() { ticket.action() }
            assert(c.snapshot.item?.title == "999" && c.snapshot.phase == .loading)
            assert(engine.loads.count == 1000)
        }
        test("load deadline is finite and late PLAY cannot leave failure") {
            let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!
            scheduler.latest.action()
            assert(c.snapshot.phase == .failed && c.snapshot.failure == .loadingTimedOut && c.requestID == nil)
            engine.emit(.playing, id); assert(c.snapshot.phase == .failed)
        }
        test("retry uses a new request identity") {
            let (c, engine, scheduler) = rig(); c.select(item()); let old = c.requestID!
            scheduler.latest.action(); c.resume()
            assert(c.snapshot.phase == .loading && c.requestID != old && engine.loads.count == 2)
        }
        test("ready and frozen progress cannot extend initial timeout") {
            let (c, engine, scheduler) = rig(); c.select(item()); let deadline = scheduler.latest
            engine.emit(.ready, c.requestID!); engine.emit(.progress(seconds: 0), c.requestID!)
            assert(scheduler.latest === deadline)
            deadline.action(); assert(c.snapshot.phase == .failed)
        }
        test("real advancing progress refreshes stall deadline") {
            let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!
            engine.emit(.playing, id); let previous = scheduler.latest
            engine.emit(.progress(seconds: 1), id)
            assert(previous.cancelled && c.snapshot.position == 1)
            previous.action(); assert(c.snapshot.phase == .playing)
            scheduler.latest.action(); assert(c.snapshot.failure == .playbackStalled)
        }
        test("stalled and invalid progress do not keep dead audio playing forever") {
            let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!
            engine.emit(.playing, id); engine.emit(.progress(seconds: 3), id)
            let deadline = scheduler.latest
            for value in [3.0, Double.nan, Double.infinity, -2] { engine.emit(.progress(seconds: value), id) }
            assert(scheduler.latest === deadline)
            deadline.action(); assert(c.snapshot.phase == .failed)
        }
        test("pause racing initial PLAY is enforced") {
            let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!
            c.pause(); assert(scheduler.latest.seconds == 8)
            engine.emit(.playing, id)
            assert(c.snapshot.phase == .loading && !c.snapshot.confirmedPlayback && engine.pauses.count == 2)
            engine.emit(.paused, id); assert(c.snapshot.phase == .paused && scheduler.latest.cancelled)
        }
        test("Play inside official widget after pause is reflected") {
            let (c, engine, _) = rig(); c.select(item()); let id = c.requestID!
            engine.emit(.playing, id); engine.emit(.paused, id)
            engine.emit(.playing, id); assert(c.snapshot.phase == .playing)
        }
        test("stop rejects queued callbacks and returns idle") {
            let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!; let deadline = scheduler.latest
            c.stop(); engine.emit(.playing, id); deadline.action()
            assert(c.snapshot == PlaybackSnapshot() && c.requestID == nil)
        }
        test("widget errors and web process termination are terminal") {
            for failure in [PlaybackFailure.widget, .webProcess, .audioSession] {
                let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!
                engine.emit(.failed(failure), id)
                assert(c.snapshot.phase == .failed && c.snapshot.failure == failure && scheduler.latest.cancelled)
                engine.emit(.playing, id); assert(c.snapshot.phase == .failed)
            }
        }
        test("finish pauses without starting another track") {
            let (c, engine, _) = rig(); c.select(item()); let id = c.requestID!
            engine.emit(.playing, id); engine.emit(.finished, id)
            assert(c.snapshot.phase == .paused && engine.pauses == [id] && engine.loads.count == 1)
        }
        test("audio interruption is reflected without auto resume") {
            let (c, engine, scheduler) = rig(); c.select(item()); let id = c.requestID!
            engine.emit(.playing, id); engine.emit(.interrupted, id)
            assert(c.snapshot.phase == .paused && scheduler.latest.cancelled && engine.resumes.isEmpty)
        }
        test("Spotify is not misrepresented as SoundCloud playback") {
            let (c, engine, _) = rig(); c.select(item(source: .spotify))
            assert(c.snapshot.failure == .unsupported && engine.loads.isEmpty)
        }
        test("mismatched or arbitrary URLs never reach engine") {
            let (c, engine, _) = rig()
            c.select(MusicItem(source: .soundCloud, url: "https://evil.example/audio", title: "x", artworkURL: nil))
            assert(c.snapshot.failure == .unsupported && engine.loads.isEmpty)
        }
        test("synchronous engine callbacks cannot race initial state") {
            let (c, engine, _) = rig()
            engine.onLoad = { id in engine.emit(.ready, id); engine.emit(.playing, id) }
            c.select(item()); assert(c.snapshot.phase == .playing)
        }
        try test("v0.1 saved items migrate without metadata loss") {
            let original = item()
            var data = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as! [String: Any]
            data.removeValue(forKey: "authorName")
            let decoded = try JSONDecoder().decode(MusicItem.self, from: JSONSerialization.data(withJSONObject: data))
            assert(decoded.id == original.id && decoded.url == original.url && decoded.authorName == nil)
        }
        try test("widget document is scoped and keeps official attribution") {
            let id = UUID(); let html = try SoundCloudWidgetDocument.html(item: item(), requestID: id, wantsPlayback: true)
            assert(html.contains(id.uuidString) && html.contains("show_user") && html.contains("soundcloud.com"))
            assert(html.contains("SC.Widget.Events.PLAY") && html.contains("isPaused"))
            assert(html.contains("height:166px") && !html.contains("display:none"))
            assert(html.contains("frame.src = config.embedURL") && html.contains("allow=\"autoplay; encrypted-media\""))
            try html.write(toFile: "/tmp/vibes-widget-test.html", atomically: true, encoding: .utf8)
        }
        try test("stored embed URL cannot inject a foreign player") {
            let malicious = MusicItem(source: .soundCloud, url: "https://soundcloud.com/forss/flickermood",
                title: "</script>", artworkURL: nil, embedURL: "https://evil.example/steal")
            let html = try SoundCloudWidgetDocument.html(item: malicious, requestID: UUID(), wantsPlayback: false)
            assert(!html.contains("evil.example") && !html.contains("</script>\""))
        }
        print("Passed: \(passed) playback coordinator/document tests")
    }
}
