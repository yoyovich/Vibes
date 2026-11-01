# Vibes v0.2 verification

## Research

Reviewed official SoundCloud Widget API, API guide/terms and WebKit media policy
before implementation (links in README). No authorized direct-stream URLs or
registered API credentials were supplied; only the official widget is used.
Public oEmbed for `forss/flickermood` returned HTTP 200, **Flickermood by Forss**
and widget track ID 293. Metadata/embed availability does not prove audio playback.

## Local evidence

- 21 actual PlaybackCoordinator/document tests with injected deterministic
  engine/timers: 1,000 switches, stale callbacks/timers, event acknowledgements,
  timeouts, retry, interruptions, v0.1 decoding and document safety.
- 10 tests execute the generated JavaScript bridge against a mock public Widget
  API: READY versus PLAY, buffering PAUSE, pause before readiness, stale PLAY,
  real event positions, finish, script errors and synchronization.
- Existing URL parsing tests pass; Swift source passes iOS-targeted syntax
  parsing. These are not UIKit type checking or real-audio verification.

## GitHub Actions

Pending publication/run. Workflow compiles for iPhone and uploads an unsigned
IPA. A separate live iOS Simulator probe then requires one library tap, official
PLAY and at least two seconds of advancing widget position, followed by a tab
switch and pause acknowledgement. No browser/iframe taps are used. Outcome,
screenshot/result bundle and logs are recorded separately: failed/skipped probe
means acceptance is unconfirmed even if compilation succeeds.

## Physical iPhone

Not executed: audible one-tap audio, real cellular/region/consent policy,
lock-screen/background continuity, audio routes and phone interruptions.
Follow `iphone-v0.2.md`. Compilation and mocked-engine tests cannot close this.
