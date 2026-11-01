# Vibes v0.2 verification — 0.2.0 (6)

## Confirmed GitHub Actions run

[Run 41326024643](https://github.com/yoyovich/Vibes/actions/runs/41326024643)
completed successfully on 2026-11-01. Tested source: `a803cb5`, containing the
app implementation from `087519e`. Documentation-only follow-up commits do not
change that app code.

- Native iPhone Release compilation and unsigned IPA packaging passed.
- Packaging read the compiled Info.plist and verified **0.2.0 / build 6**.
- 21 actual PlaybackCoordinator/document tests, 10 generated-JavaScript bridge
  tests and the existing URL parser tests passed on the macOS runner.
- **Live iOS Simulator integration passed:** iPhone 17 Pro, iOS 26.5, arm64.
  The app was launched with its Debug-only public library fixture. There was
  exactly one playback-start tap, on the native Library row for **Forss —
  Flickermood**. There were no iframe taps or browser-screen interactions.
- The official Widget API produced PLAY (verified through isPaused), and its
  reported position advanced. The native UI log captured:
  `LIVE_WIDGET_PLAY_AND_PROGRESS_CONFIRMED: playing|22.654486`.
- The same test switched to Search, verified the dock remained, pressed native
  Pause and received paused state. XCTest: 1 test passed, 0 failures.

Download evidence:
- [Unsigned IPA artifact](https://github.com/yoyovich/Vibes/actions/runs/41326024643/artifacts/13091675521)
- [Live summary, screenshot/result bundle and logs](https://github.com/yoyovich/Vibes/actions/runs/41326024643/artifacts/13091128850)

The screenshot was visually reviewed: official creator/source branding and
controls remain visible. SoundCloud's own mobile promotion overlay is also
visible; it was neither clicked nor suppressed. This test proves real widget
reported start/progress in Simulator, not audible physical-device output or
completion of the entire track. It does not establish full-length playback for
every public track; provider preview/availability limits still apply.

## Corrections found during validation

Earlier native builds compiled, but live UI checks failed before audio was
confirmed. Plain library labels now have a full rectangular hit region. An idle
zero-height WKWebView was removed from the hit-test hierarchy; the engine/view
object itself stays retained and is reused when a track is selected. The
corrected live test verifies idle WebView absence, native tab navigation and
actual playback. No mocked player is linked into the app.

An inspection of an earlier compiled IPA also found XcodeGen's default 1.0 (1)
metadata overriding project settings. Info.plist now expands MARKETING_VERSION
and CURRENT_PROJECT_VERSION, and packaging checks actual compiled values.

macOS 15 queue delays and an Intel simulator cold-start exceeding the probe's
12-minute limit were infrastructure failures, not evidence of SoundCloud policy
rejection. The final successful run used standard ARM macOS 26 (not a paid larger
runner). Failed probes now fail the workflow rather than being hidden by
continue-on-error. Diagnostics and the complete job have time limits.

## Research and deterministic checks

Reviewed official SoundCloud Widget API, API guide/terms and WebKit media policy
before implementation (README links). No authorized direct stream URLs or API
credentials were provided; only the official widget is used. Public oEmbed for
`forss/flickermood` returned HTTP 200, the title/creator and widget track ID 293.
Metadata availability alone was not treated as proof of playback.

Coordinator tests inject engine/timers to verify 1,000 switches, stale callbacks,
real-event state transitions, deadlines, retry, interruptions and v0.1 decoding.
Bridge tests execute the actual generated JavaScript with a mock public Widget
API. Those deterministic tests are separate from the successful real-network
native UI integration above.

## Still requires a physical iPhone

Not executed: audible output on hardware, full-track duration, real cellular/
regional/consent behavior, background/lock-screen continuity, audio routes,
phone interruptions and manual Spotify regression. Follow `iphone-v0.2.md`.
A native build, event/progress trace or Simulator screenshot cannot close these
physical-device checks. No guaranteed background audio or native lock-screen
remote controls are claimed.
