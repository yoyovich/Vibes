import Foundation

enum PlaybackPhase: String, Equatable { case idle, loading, playing, paused, failed }

enum PlaybackFailure: String, Equatable {
    case unsupported, loadingTimedOut, playbackStalled, widget, webProcess, audioSession

    var message: String {
        switch self {
        case .unsupported: return "Этот плеер предназначен для публичных ссылок SoundCloud."
        case .loadingTimedOut:
            return "SoundCloud не подтвердил запуск. Возможны проблемы сети, недоступная запись или блокировка автозапуска WebKit. Повтори запуск или открой оригинал по ссылке SoundCloud."
        case .playbackStalled: return "SoundCloud перестал передавать события воспроизведения. Проверь интернет и повтори запуск."
        case .widget: return "SoundCloud не смог воспроизвести запись. Она может быть удалена, ограничена или недоступна для встраивания."
        case .webProcess: return "Веб-плеер был остановлен системой. Повтори запуск."
        case .audioSession: return "Не удалось активировать аудио на устройстве."
        }
    }
}

struct PlaybackSnapshot: Equatable {
    var phase: PlaybackPhase = .idle
    var item: MusicItem?
    var failure: PlaybackFailure?
    var position: Double = 0
    var confirmedPlayback = false
}

enum PlaybackEvent {
    case ready, playing, paused, finished, interrupted
    case progress(seconds: Double)
    case failed(PlaybackFailure)
}

/// A single engine, shared by the entire app. Every callback carries the
/// document/request identity, so cancelled track A cannot alter track B.
@MainActor
protocol PlaybackEngine: AnyObject {
    var onEvent: ((UUID, PlaybackEvent) -> Void)? { get set }
    func load(_ item: MusicItem, requestID: UUID)
    func resume(requestID: UUID)
    func pause(requestID: UUID)
    func stop()
}

@MainActor
protocol PlaybackCancellation: AnyObject { func cancel() }

@MainActor
protocol PlaybackScheduler {
    func schedule(after seconds: Double, action: @escaping @MainActor () -> Void) -> any PlaybackCancellation
}

@MainActor
struct TaskPlaybackScheduler: PlaybackScheduler {
    private final class Timer: PlaybackCancellation {
        var task: Task<Void, Never>?
        func cancel() { task?.cancel(); task = nil }
    }
    func schedule(after seconds: Double, action: @escaping @MainActor () -> Void) -> any PlaybackCancellation {
        let timer = Timer()
        timer.task = Task { @MainActor in
            do { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled else { return }
            action()
        }
        return timer
    }
}

/// No state is inferred from a successful JS evaluation or a play command.
/// playing/paused come from engine events; loading always has a deadline.
@MainActor
final class PlaybackCoordinator {
    private(set) var snapshot = PlaybackSnapshot() {
        didSet { if snapshot != oldValue { onChange?(snapshot) } }
    }
    var onChange: ((PlaybackSnapshot) -> Void)?
    private(set) var requestID: UUID?
    private let engine: any PlaybackEngine
    private let scheduler: any PlaybackScheduler
    private var timer: (any PlaybackCancellation)?
    private var deadlineID = UUID()
    private var wantsPlayback = false

    init(engine: any PlaybackEngine, scheduler: (any PlaybackScheduler)? = nil) {
        self.engine = engine; self.scheduler = scheduler ?? TaskPlaybackScheduler()
        engine.onEvent = { [weak self] id, event in self?.receive(event, requestID: id) }
    }

    func select(_ item: MusicItem) {
        invalidateDeadline()
        requestID = nil
        engine.stop()
        wantsPlayback = true
        let id = UUID()
        requestID = id
        snapshot = PlaybackSnapshot(phase: .loading, item: item)
        guard item.source == .soundCloud, item.mediaLink?.source == .soundCloud else {
            fail(.unsupported); return
        }
        armDeadline(seconds: 30, failure: .loadingTimedOut)
        engine.load(item, requestID: id)
    }

    func pause() {
        guard let id = requestID, snapshot.phase == .playing || snapshot.phase == .loading else { return }
        wantsPlayback = false
        snapshot.phase = .loading
        armDeadline(seconds: 8, failure: .playbackStalled)
        engine.pause(requestID: id)
    }

    func resume() {
        guard let item = snapshot.item else { return }
        if snapshot.phase == .failed { select(item); return }
        guard snapshot.phase == .paused, let id = requestID else { return }
        wantsPlayback = true
        snapshot.phase = .loading
        armDeadline(seconds: 30, failure: .loadingTimedOut)
        engine.resume(requestID: id)
    }

    func stop() {
        invalidateDeadline(); requestID = nil; wantsPlayback = false
        engine.stop(); snapshot = PlaybackSnapshot()
    }

    func receive(_ event: PlaybackEvent, requestID id: UUID) {
        guard requestID == id, snapshot.phase != .failed else { return }
        switch event {
        case .ready: break // Widget READY is not evidence of audio playback.
        case .playing:
            // A user can also press Play inside the official widget after a
            // pause. Reject only a PLAY racing an outstanding native pause.
            if !wantsPlayback && snapshot.phase == .loading { engine.pause(requestID: id); return }
            wantsPlayback = true
            snapshot.phase = .playing
            snapshot.failure = nil
            snapshot.confirmedPlayback = true
            armDeadline(seconds: 20, failure: .playbackStalled)
        case .paused, .interrupted:
            wantsPlayback = false; invalidateDeadline()
            snapshot.phase = .paused
        case .finished:
            wantsPlayback = false; invalidateDeadline()
            snapshot.phase = .paused
            engine.pause(requestID: id) // No cross-track or cross-service auto queue.
        case .progress(let seconds):
            guard wantsPlayback, seconds.isFinite, seconds >= 0,
                  snapshot.phase == .playing, seconds != snapshot.position else { return }
            snapshot.position = seconds
            armDeadline(seconds: 20, failure: .playbackStalled)
        case .failed(let failure): fail(failure)
        }
    }

    private func fail(_ failure: PlaybackFailure) {
        invalidateDeadline(); requestID = nil; wantsPlayback = false
        engine.stop()
        snapshot.phase = .failed; snapshot.failure = failure
    }
    private func invalidateDeadline() {
        deadlineID = UUID(); timer?.cancel(); timer = nil
    }
    private func armDeadline(seconds: Double, failure: PlaybackFailure) {
        invalidateDeadline()
        let generation = deadlineID
        let request = requestID
        timer = scheduler.schedule(after: seconds) { [weak self] in
            guard let self, self.deadlineID == generation, self.requestID == request else { return }
            self.fail(failure)
        }
    }
}
