# Vibes v0.2 — One-Tap Playback

SwiftUI iPhone prototype. Public SoundCloud links use the **official SoundCloud
Widget API** inside one persistent WKWebView. Spotify search, saved links and
its official embeds remain separate. No new project/repository, backend, paid
APIs, protected-stream extraction or borrowed API keys.

## Playback

Import a public link on Search, then tap its saved Library row **once**. The
persistent dock requests playback without a browser sheet. Switching tabs does
not recreate the engine. Choosing another track pauses old media, cancels old
navigation, replaces the iframe document inside the same WKWebView and rejects
abandoned request IDs. The official widget stays visible with its creator,
artwork, branding, links, controls and service restrictions/advertising intact.

`PlaybackCoordinator` owns idle/loading/playing/paused/failed. Only official PLAY
and PAUSE events verified through `isPaused` change actual playback states.
READY, a play command or successful JavaScript evaluation is not evidence of
playing. Position comes from official PLAY_PROGRESS events. Start/resume has a
30s deadline, pause acknowledgement 8s; 20s without advancing playback events
ends a stalled foreground session. Retry is explicit; loading is asynchronous.

One dock and one engine live outside TabView. Search browser and Spotify sheet
openings stop SoundCloud first; dismissed browser sheets stop/unload their own
media. No simultaneous sources or cross-service queue. Spotify decides whether
its embed offers full playback, a preview or none; neither a preview nor a link
launch is labelled as full/native Spotify playback. App Remote is not added.

## Verification and limits

Local: **21 coordinator/document tests**, **10 generated-JavaScript bridge tests**,
existing URL tests and iOS-targeted Swift syntax parsing pass. These test
1,000 switches, stale callbacks/timers, real event-driven states, failures,
retry, migration and initial paused/buffering behavior. They do not prove audio.

GitHub Actions builds an unsigned iPhone IPA, then independently tries live
SoundCloud playback in iOS Simulator: one Library tap on **Forss — Flickermood**
must produce official PLAY and advancing position for at least two seconds,
then survive a tab switch and acknowledge Pause. No iframe/browser taps. Its
outcome and evidence are recorded separately. An IPA or green compilation alone
is **not one-tap acceptance**. See [observed verification](docs/verification-v0.2.md)
and [physical-iPhone scenarios](docs/iphone-v0.2.md).

No physical-iPhone audio verification is available in this workspace. Embedded
WebKit/SoundCloud background or locked-screen continuity is **not promised**;
AVAudioSession playback configuration cannot guarantee it. Native remote
lock-screen controls are not implemented.

## Autoplay and realistic alternatives

Before WKWebView creation the app sets the public
`mediaTypesRequiringUserActionForPlayback = []` policy; the visible iframe allows
autoplay. Widget READY asks native code to authorize the latest play/pause intent. A SwiftUI tap is not a trusted
JavaScript gesture; no synthetic clicks or private WebKit preferences are used.
SoundCloud's mobile policy, regional/owner restrictions or consent can still
block startup. Missing PLAY becomes an explicit timeout, not simulated success.

Manual Play in the visible official widget before timeout is a realistic
fallback/diagnostic if permitted autoplay fails, but **does not satisfy one tap**.
The SoundCloud original link is explicitly external. Authorized native streaming
would require suitable registered access/licensing; none is supplied here. No
protected URL scraping is used to substitute for it, and not every public link
is guaranteed playable in full.

## Service terms

Widgets do not grant a general license for an alternative streaming service.
SoundCloud terms restrict on-demand aggregation and cross-service playback;
appropriate permission is needed before offering such a service. This prototype
retains the official player/attribution and never removes ads or persists audio.
That is an implementation choice, not a claim of SoundCloud approval. No mixed
Spotify/SoundCloud audio experience is provided.

## Build

Repository: https://github.com/yoyovich/Vibes

Actions → **Build unsigned iOS IPA** → download `Vibes-unsigned-IPA`. Sign with
your own valid certificate/profile before installing. Version **0.2.0 (3)**;
bundle ID `com.yoyovich.vibes`.

On a Mac:

```sh
swiftc Sources/MediaLink.swift Tests/MediaLinkTests.swift -o /tmp/vibes-links
/tmp/vibes-links
swiftc -parse-as-library Sources/MediaLink.swift Sources/MusicItem.swift Sources/PlaybackCoordinator.swift Sources/SoundCloudWidgetDocument.swift Tests/PlaybackCoordinatorTests.swift -o /tmp/vibes-playback
/tmp/vibes-playback
node Tests/WidgetBridgeTests.js /tmp/vibes-widget-test.html
brew install xcodegen
xcodegen generate
open Vibes.xcodeproj
```

`VibesUITests` is a live external-network integration probe. The Debug-only
`--soundcloud-smoke` launch argument adds its public fixture, never auto-starts
audio and is absent from Release code. Existing v0.1 saved items migrate without
requiring the new optional creator metadata.

## Primary sources researched

- [Widget API](https://developers.soundcloud.com/docs/api/html5-widget): supported controls, events, visible iframe.
- [oEmbed](https://developers.soundcloud.com/docs/oembed): metadata/embed, not stream authorization.
- [SoundCloud API guide](https://developers.soundcloud.com/docs/api/guide): registered streaming access.
- [API terms](https://developers.soundcloud.com/docs/api/terms-of-use) and [widget/user terms](https://soundcloud.com/terms-of-use).
- [WebKit configuration](https://developer.apple.com/documentation/webkit/wkwebviewconfiguration/mediatypesrequiringuseractionforplayback) and [iOS media policy](https://webkit.org/blog/6784/new-video-policies-for-ios/).
- [Spotify embeds](https://developer.spotify.com/documentation/embeds).
