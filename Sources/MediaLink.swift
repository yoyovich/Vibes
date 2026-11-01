import Foundation

enum MusicSource: String, Codable, CaseIterable, Identifiable {
    case soundCloud = "soundcloud"
    case spotify = "spotify"

    var id: String { rawValue }
    var title: String { self == .soundCloud ? "SoundCloud" : "Spotify" }

    var searchBaseURL: String {
        switch self {
        case .soundCloud: return "https://soundcloud.com/search/sounds"
        case .spotify: return "https://open.spotify.com/search"
        }
    }

    func searchURL(for query: String) -> URL? {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        switch self {
        case .soundCloud:
            var components = URLComponents(string: searchBaseURL)!
            components.queryItems = [URLQueryItem(name: "q", value: query)]
            return components.url
        case .spotify:
            // Set path through URLComponents so query input cannot change the hostname.
            var components = URLComponents(string: "https://open.spotify.com")!
            components.path = "/search/" + query
            return components.url
        }
    }
}

struct MediaLink: Equatable {
    let source: MusicSource
    let url: URL

    static func parse(_ string: String) -> MediaLink? {
        let raw = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let input = raw.contains("://") ? raw : "https://" + raw
        guard var parts = URLComponents(string: input),
              let host = parts.host?.lowercased(),
              ["http", "https"].contains(parts.scheme?.lowercased() ?? "")
        else { return nil }

        parts.scheme = "https"
        parts.fragment = nil
        parts.query = nil // v0.1 supports public content only
        let sections = parts.path.split(separator: "/").map(String.init)

        if ["soundcloud.com", "www.soundcloud.com", "m.soundcloud.com"].contains(host) {
            let forbidden: Set<String> = ["search", "discover", "charts", "you", "stream", "settings", "login", "upload", "feed"]
            guard sections.count >= 2, !forbidden.contains(sections[0].lowercased()) else { return nil }
            parts.host = "soundcloud.com"
            guard let normalized = parts.url else { return nil }
            return MediaLink(source: .soundCloud, url: normalized)
        }
        if host == "open.spotify.com" {
            // Spotify sometimes prefixes the path with a locale like intl-en.
            let relevant = sections.first?.hasPrefix("intl-") == true ? Array(sections.dropFirst()) : sections
            guard relevant.count >= 2,
                  ["track", "album", "playlist", "episode", "show", "artist"].contains(relevant[0]),
                  !relevant[1].isEmpty else { return nil }
            parts.path = "/" + relevant[0] + "/" + relevant[1]
            guard let normalized = parts.url else { return nil }
            return MediaLink(source: .spotify, url: normalized)
        }
        return nil
    }

    var embedURL: URL? {
        switch source {
        case .soundCloud:
            var components = URLComponents(string: "https://w.soundcloud.com/player/")!
            components.queryItems = [
                URLQueryItem(name: "url", value: url.absoluteString),
                URLQueryItem(name: "color", value: "#ff5500"),
                URLQueryItem(name: "auto_play", value: "false"),
                URLQueryItem(name: "show_comments", value: "false")
            ]
            return components.url
        case .spotify:
            var components = URLComponents(string: "https://open.spotify.com")!
            components.path = "/embed" + url.path
            return components.url
        }
    }
}
