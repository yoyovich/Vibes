import Foundation

@main
struct MediaLinkTests {
    static func main() {
        let sc = MediaLink.parse("https://soundcloud.com/example/track?utm_source=share")
        assert(sc?.source == .soundCloud)
        assert(sc?.url.absoluteString == "https://soundcloud.com/example/track")
        assert(sc?.embedURL?.host == "w.soundcloud.com")
        let spotify = MediaLink.parse("https://open.spotify.com/intl-en/track/abc123?si=zzz")
        assert(spotify?.source == .spotify)
        assert(spotify?.url.absoluteString == "https://open.spotify.com/track/abc123")
        assert(spotify?.embedURL?.absoluteString == "https://open.spotify.com/embed/track/abc123")
        assert(MediaLink.parse("https://soundcloud.com/search/sounds?q=track") == nil)
        assert(MediaLink.parse("https://open.spotify.com/search/love") == nil)
        assert(MediaLink.parse("https://evil.example/track/123") == nil)
        assert(MusicSource.soundCloud.searchURL(for: "my music")?.host == "soundcloud.com")
        assert(MusicSource.spotify.searchURL(for: "AC/DC")?.host == "open.spotify.com")
        print("Passed: URL parsing and source search tests")
    }
}
