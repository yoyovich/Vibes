import SwiftUI
import WebKit
import AVFAudio

@MainActor
final class SoundCloudPlaybackEngine: NSObject, PlaybackEngine, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    var onEvent: ((UUID, PlaybackEvent) -> Void)?
    private var requestID: UUID?
    private var wantsPlayback = false
    private var navigation: WKNavigation?
    private var interruptionObserver: NSObjectProtocol?
    private var routeObserver: NSObjectProtocol?
    private let bridge = MessageBridge()

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // Public WKWebView policy, configured before the web view is created.
        // A SwiftUI tap is not a JavaScript user gesture. We do not synthesize
        // clicks, extract streams or override SoundCloud's own restrictions.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController.add(bridge, name: "playback")
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        bridge.owner = self
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.accessibilityIdentifier = "soundcloud-widget"
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                == AVAudioSession.InterruptionType.began.rawValue
            guard began else { return }
            Task { @MainActor [weak self] in
                guard let self, let id = self.requestID else { return }
                self.pause(requestID: id); self.onEvent?(id, .interrupted)
            }
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] notification in
            let unplugged = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            guard unplugged else { return }
            Task { @MainActor [weak self] in
                guard let self, let id = self.requestID else { return }
                self.pause(requestID: id)
            }
        }
    }

    func load(_ item: MusicItem, requestID id: UUID) {
        requestID = id; wantsPlayback = true; navigation = nil
        webView.stopLoading()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { onEvent?(id, .failed(.audioSession)); return }
        // Await the old media's pause before loading a replacement document.
        // Completion callbacks from an abandoned selection cannot load/play.
        webView.pauseAllMediaPlayback { [weak self] in
            guard let self, self.requestID == id else { return }
            do {
                let html = try SoundCloudWidgetDocument.html(item: item, requestID: id,
                                                            wantsPlayback: self.wantsPlayback)
                self.navigation = self.webView.loadHTMLString(html, baseURL: URL(string: "https://vibes.invalid/"))
            } catch { self.onEvent?(id, .failed(.widget)) }
        }
    }

    func resume(requestID id: UUID) {
        guard requestID == id else { return }
        wantsPlayback = true
        do { try AVAudioSession.sharedInstance().setActive(true) }
        catch { onEvent?(id, .failed(.audioSession)); return }
        command("play", requestID: id)
    }
    func pause(requestID id: UUID) {
        guard requestID == id else { return }
        wantsPlayback = false
        command("pause", requestID: id)
        webView.pauseAllMediaPlayback(completionHandler: nil)
    }
    func stop() {
        requestID = nil; wantsPlayback = false; navigation = nil
        webView.stopLoading()
        webView.pauseAllMediaPlayback { [weak self] in
            guard let self, self.requestID == nil else { return }
            self.webView.loadHTMLString("<!doctype html><html><body></body></html>", baseURL: nil)
        }
    }
    func synchronize() {
        if let id = requestID { command("sync", requestID: id) }
    }
    private func command(_ action: String, requestID id: UUID) {
        // Optional chaining deliberately permits commands during document setup;
        // didFinish reapplies the most recent intent, not an obsolete one.
        webView.evaluateJavaScript("window.VibesWidget?.\(action)()") { [weak self] _, error in
            guard let self, self.requestID == id else { return }
            // Setup may not have installed the bridge yet; the overall load
            // deadline handles failure instead of reporting false playback.
            if let error = error as NSError?, error.code == WKError.webContentProcessTerminated.rawValue {
                self.onEvent?(id, .failed(.webProcess))
            }
        }
    }
    private func received(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame,
              let body = message.body as? [String: Any],
              let rawID = body["requestID"] as? String, let id = UUID(uuidString: rawID), id == requestID,
              let event = body["event"] as? String else { return }
        switch event {
        case "ready": onEvent?(id, .ready)
        case "playing": wantsPlayback = true; onEvent?(id, .playing)
        case "paused": wantsPlayback = false; onEvent?(id, .paused)
        case "finished": wantsPlayback = false; onEvent?(id, .finished)
        case "progress":
            if let seconds = body["seconds"] as? Double { onEvent?(id, .progress(seconds: seconds)) }
        case "error": onEvent?(id, .failed(.widget))
        default: break
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let navigation, navigation === self.navigation, let id = requestID else { return }
        command(wantsPlayback ? "play" : "pause", requestID: id)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        navigationFailed(navigation, error: error)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        navigationFailed(navigation, error: error)
    }
    private func navigationFailed(_ navigation: WKNavigation?, error: Error) {
        guard let navigation, navigation === self.navigation, let id = requestID,
              (error as NSError).code != NSURLErrorCancelled else { return }
        onEvent?(id, .failed(.widget))
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if let id = requestID { onEvent?(id, .failed(.webProcess)) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url,
           ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        } else if action.targetFrame?.isMainFrame == true,
                  let url = action.request.url, url.scheme != "about", url.host != "vibes.invalid" {
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.navigationType == .linkActivated, let url = action.request.url,
           ["https", "http"].contains(url.scheme?.lowercased() ?? "") { UIApplication.shared.open(url) }
        return nil
    }
    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    }
    private final class MessageBridge: NSObject, WKScriptMessageHandler {
        weak var owner: SoundCloudPlaybackEngine?
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            owner?.received(message)
        }
    }
}

@MainActor
final class PlaybackStore: ObservableObject {
    let engine: SoundCloudPlaybackEngine
    let coordinator: PlaybackCoordinator
    @Published private(set) var snapshot = PlaybackSnapshot()
    init() {
        let engine = SoundCloudPlaybackEngine()
        self.engine = engine
        coordinator = PlaybackCoordinator(engine: engine)
        coordinator.onChange = { [weak self] in self?.snapshot = $0 }
    }
}

struct SoundCloudWidgetView: UIViewRepresentable {
    let engine: SoundCloudPlaybackEngine
    func makeUIView(context: Context) -> WKWebView { engine.webView }
    func updateUIView(_ uiView: WKWebView, context: Context) { }
}

struct PlaybackDock: View {
    @EnvironmentObject private var playback: PlaybackStore
    private var snapshot: PlaybackSnapshot { playback.snapshot }
    var body: some View {
        VStack(spacing: 0) {
            if let item = snapshot.item {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(status).font(.caption).foregroundStyle(.secondary)
                            .accessibilityValue("\(snapshot.phase.rawValue)|\(snapshot.position)")
                            .accessibilityIdentifier("playback-state")
                    }
                    Spacer(minLength: 4)
                    if snapshot.phase == .loading { ProgressView().controlSize(.small) }
                    Button {
                        if snapshot.phase == .playing || snapshot.phase == .loading { playback.coordinator.pause() }
                        else { playback.coordinator.resume() }
                    } label: {
                        Image(systemName: snapshot.phase == .playing || snapshot.phase == .loading ? "pause.fill" : "play.fill")
                            .frame(width: 40, height: 44)
                    }.accessibilityLabel(snapshot.phase == .playing || snapshot.phase == .loading ? "Пауза" : "Воспроизвести")
                        .accessibilityIdentifier("playback-toggle")
                    Button { playback.coordinator.stop() } label: {
                        Image(systemName: "xmark").frame(width: 32, height: 44)
                    }.accessibilityLabel("Закрыть плеер")
                }.padding(.horizontal, 12)
                if let failure = snapshot.failure {
                    Text(failure.message).font(.caption).foregroundStyle(.orange).padding(.horizontal, 12).padding(.bottom, 8)
                        .accessibilityIdentifier("playback-error")
                }
            }
            // Keep this representable at one stable identity, outside TabView.
            // The official controls/artwork/creator/branding are never covered.
            SoundCloudWidgetView(engine: playback.engine)
                .frame(height: snapshot.item == nil ? 0 : 166)
                .accessibilityHidden(snapshot.item == nil)
            if let item = snapshot.item, let url = item.mediaLink?.url {
                Link("SoundCloud · \(item.authorName ?? "Открыть оригинал")", destination: url)
                    .font(.caption2).padding(6)
            }
        }
        .background(.regularMaterial)
    }
    private var status: String {
        switch snapshot.phase {
        case .idle: return "SoundCloud"
        case .loading: return "Загрузка SoundCloud…"
        case .playing: return "Воспроизводится · SoundCloud"
        case .paused: return "Пауза · SoundCloud"
        case .failed: return "Не удалось запустить · SoundCloud"
        }
    }
}
