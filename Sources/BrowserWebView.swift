import SwiftUI
import WebKit

struct BrowserWebView: UIViewRepresentable {
    let initialURL: URL
    @Binding var currentURL: URL?
    @Binding var failure: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        context.coordinator.watch(view)
        view.load(URLRequest(url: initialURL))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.owner = self
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var owner: BrowserWebView
        private var observation: NSKeyValueObservation?

        init(_ owner: BrowserWebView) { self.owner = owner }

        func watch(_ webView: WKWebView) {
            observation = webView.observe(\.url, options: [.new]) { [weak self] _, change in
                DispatchQueue.main.async { self?.owner.currentURL = change.newValue ?? nil }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            owner.currentURL = webView.url
            owner.failure = nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else { return }
            owner.failure = "Не удалось открыть каталог: \(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
