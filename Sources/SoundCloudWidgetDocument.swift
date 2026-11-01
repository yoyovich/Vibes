import Foundation

/// The only web audio surface is the unmodified, visible official widget.
/// Loading a fresh document on track selection destroys the old iframe and
/// scopes all asynchronous widget callbacks to a unique request identity.
enum SoundCloudWidgetDocument {
    enum DocumentError: Error { case invalidLink }
    static func html(item: MusicItem, requestID: UUID, wantsPlayback: Bool) throws -> String {
        guard let link = item.mediaLink, link.source == .soundCloud else { throw DocumentError.invalidLink }
        var parts = URLComponents(string: "https://w.soundcloud.com/player/")!
        parts.queryItems = [
            URLQueryItem(name: "url", value: link.url.absoluteString),
            URLQueryItem(name: "auto_play", value: "false"),
            URLQueryItem(name: "visual", value: "false"),
            URLQueryItem(name: "show_user", value: "true"),
            URLQueryItem(name: "show_artwork", value: "true"),
            URLQueryItem(name: "single_active", value: "true")
        ]
        let config: [String: Any] = ["requestID": requestID.uuidString,
                                     "embedURL": parts.url!.absoluteString,
                                     "wantsPlayback": wantsPlayback]
        let data = try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys])
        let json = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;padding:0;background:#fff}iframe{display:block;width:100%;height:166px;border:0}</style>
        </head><body>
        <iframe id="soundcloud" title="SoundCloud player" allow="autoplay; encrypted-media" scrolling="no"></iframe>
        <script>
        (() => {
          'use strict';
          const config = \(json);
          let widget = null, ready = false, desired = config.wantsPlayback, hasPlayed = false;
          let lastProgress = 0;
          function emit(event, fields = {}) {
            window.webkit.messageHandlers.playback.postMessage(
              Object.assign({requestID: config.requestID, event}, fields));
          }
          function apply() {
            if (!ready) return;
            if (desired) widget.play();
            else {
              widget.pause();
              widget.isPaused(value => { if (value) emit('paused'); });
            }
          }
          window.VibesWidget = {
            play() { desired = true; apply(); },
            pause() { desired = false; apply(); },
            sync() {
              if (!ready) return;
              widget.isPaused(paused => { if (paused) emit('paused'); });
            }
          };
          window.vibesWidgetScriptFailed = () => emit('error');
          window.vibesWidgetScriptReady = () => {
            const frame = document.getElementById('soundcloud');
            frame.src = config.embedURL;
            widget = SC.Widget(frame);
            widget.bind(SC.Widget.Events.READY, () => {
              ready = true; emit('ready'); apply();
            });
            widget.bind(SC.Widget.Events.PLAY, () => {
              widget.isPaused(paused => {
                if (!paused) { hasPlayed = true; desired = true; emit('playing'); }
              });
            });
            widget.bind(SC.Widget.Events.PAUSE, () => {
              // The initial paused widget can report PAUSE while the first
              // play request is still buffering. That is not a user pause.
              if (ready && (hasPlayed || !desired)) widget.isPaused(paused => {
                if (paused) { desired = false; emit('paused'); }
              });
            });
            widget.bind(SC.Widget.Events.FINISH, () => {
              desired = false; widget.pause(); emit('finished');
            });
            widget.bind(SC.Widget.Events.ERROR, () => emit('error'));
            widget.bind(SC.Widget.Events.PLAY_PROGRESS, event => {
              const now = Date.now();
              if (now - lastProgress < 1000) return;
              lastProgress = now;
              emit('progress', {seconds: event.currentPosition / 1000});
            });
          };
        })();
        </script>
        <script src="https://w.soundcloud.com/player/api.js" onload="vibesWidgetScriptReady()" onerror="vibesWidgetScriptFailed()"></script>
        </body></html>
        """
    }
}
