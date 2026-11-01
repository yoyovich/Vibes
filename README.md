# Vibes — iOS zero-budget prototype (v0.1)

A native **SwiftUI shell** for two music sources: **SoundCloud (required)** and Spotify. No paid APIs, personal backend, or third-party dependencies.

## What v0.1 actually does

- Source-specific search inside an embedded browser (SoundCloud / Spotify public website).
- Save public track (or supported album/playlist) links either from the embedded page or by pasting a URL.
- Fetch metadata through each platform's *official public oEmbed* endpoint, without API credentials.
- Store saved links locally and show them in one library; remove with swipe.
- Play supported public SoundCloud content in SoundCloud's official embedded player.
- Show Spotify's official embed; Spotify controls whether the listener receives a full track, preview or no playback.
- Surface network failures and request timeouts instead of silently failing.

**Not implemented yet:** unified native search-result cards, native background audio and lock-screen controls, cross-service queue, automatic matching of Spotify and SoundCloud tracks, full Spotify playback without Spotify restrictions, download/offline playback. The SoundCloud website search may redirect to login or behave differently by region. Any embedded browser can fail due to platform changes; there is no guarantee of crash-free operation.

## Architecture

```
SwiftUI search / library
    |
    +-- MusicSource & MediaLink -> restricted URL parsing and search routes
    +-- BrowserWebView (WKWebView) -> service-specific search
    +-- OEmbedClient (URLSession) -> public metadata
    +-- LibraryStore (UserDefaults) -> saved links
    +-- PlayerScreen (WKWebView) -> SoundCloud/Spotify official embed
```

The source modules are isolated so later native search and different playback backends can replace the browser and embed components. This prototype does **not** copy or decrypt protected streams.

## Build on GitHub without a Mac

1. Create a public GitHub repository (GitHub-hosted macOS runner minutes are generally free on public repos; confirm your account's Actions policies).
2. Upload the contents of this folder, including `.github/workflows/build-ios.yml`.
3. Open **Actions → Build unsigned iOS IPA → Run workflow**.
4. Download the `Vibes-unsigned-IPA` artifact once the build succeeds.
5. Import the unsigned IPA into your iOS signing tool and sign it with your **own certificate and provisioning profile**, using an appropriate bundle ID. Then install on your iPhone. An unsigned IPA alone cannot be launched on iOS.

The workflow uses XcodeGen to construct the `.xcodeproj` from `project.yml`. It compiles for **iPhone**, not Simulator.

If you later have a Mac: `brew install xcodegen && xcodegen generate && open Vibes.xcodeproj`.

## Run the source-only parser test (Swift installed)

```sh
swiftc Sources/MediaLink.swift Tests/MediaLinkTests.swift -o /tmp/vibes-parser-tests
/tmp/vibes-parser-tests
```

## Limitations / terms

Official SoundCloud API keys for **new** apps require Artist Pro; this app uses SoundCloud's separate publicly documented oEmbed and Widget interfaces. Public embeds may not work for geo-restricted, removed, private or subscription-only media. Spotify's official Embed decides whether full playback is available or the user gets a preview, and its Web API is not required by this prototype. Service terms and the available embed experience still apply.

## References

- SoundCloud oEmbed: https://developers.soundcloud.com/docs/oembed
- SoundCloud Widget API: https://developers.soundcloud.com/docs/api/html5-widget
- Spotify oEmbed: https://developer.spotify.com/documentation/embeds/reference/oembed
- Spotify Embeds: https://developer.spotify.com/documentation/embeds
- Parachord iOS architecture (reference only; no copied source): https://github.com/Parachord/parachord-mobile
