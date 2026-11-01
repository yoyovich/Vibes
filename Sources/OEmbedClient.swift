import Foundation

enum ImportError: LocalizedError {
    case invalidLink
    case invalidResponse
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "Нужна ссылка на трек, альбом или плейлист SoundCloud/Spotify."
        case .invalidResponse:
            return "Музыкальный сервис вернул неожиданный ответ. Попробуй снова."
        case .notAvailable:
            return "Этот материал недоступен для встраивания или сервис временно не отвечает."
        }
    }
}

struct OEmbedPayload: Decodable {
    let title: String
    let thumbnailURL: String?
    let html: String?
    let authorName: String?

    enum CodingKeys: String, CodingKey {
        case title
        case thumbnailURL = "thumbnail_url"
        case html
        case authorName = "author_name"
    }
}

struct OEmbedClient {
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        return URLSession(configuration: configuration)
    }()

    // Prefer SoundCloud's own embed URL. The oEmbed response resolves a
    // public permalink into the numeric track/playlist identifier needed by
    // the widget; guessing an embed URL from the permalink is less reliable.
    private static func soundCloudPlayerURL(in html: String?) -> URL? {
        guard let html,
              let expression = try? NSRegularExpression(pattern: #"<iframe[^>]*\bsrc=[\"']([^\"']+)[\"']"#, options: [.caseInsensitive]),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let capture = Range(match.range(at: 1), in: html) else { return nil }
        let rawURL = String(html[capture]).replacingOccurrences(of: "&amp;", with: "&")
        guard let url = URL(string: rawURL), url.scheme == "https", url.host == "w.soundcloud.com" else { return nil }
        return url
    }

    func importLink(_ rawURL: String) async throws -> MusicItem {
        var raw = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.contains("://") { raw = "https://" + raw }
        guard let initial = URL(string: raw), let host = initial.host?.lowercased() else {
            throw ImportError.invalidLink
        }

        var candidateURL = initial
        if ["on.soundcloud.com", "spotify.link"].contains(host) {
            var request = URLRequest(url: initial)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 12
            do {
                var (_, response) = try await session.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 405 {
                    request.httpMethod = "GET"
                    (_, response) = try await session.data(for: request)
                }
                candidateURL = response.url ?? initial
            } catch {
                throw ImportError.notAvailable
            }
        }

        guard let link = MediaLink.parse(candidateURL.absoluteString) else {
            throw ImportError.invalidLink
        }

        let endpoint: String = link.source == .soundCloud
            ? "https://soundcloud.com/oembed"
            : "https://open.spotify.com/oembed"
        var parts = URLComponents(string: endpoint)!
        parts.queryItems = [
            URLQueryItem(name: "url", value: link.url.absoluteString),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let endpointURL = parts.url else { throw ImportError.invalidLink }

        var request = URLRequest(url: endpointURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw ImportError.invalidResponse
        }
        guard (200..<300).contains(status) else { throw ImportError.notAvailable }
        guard let payload = try? JSONDecoder().decode(OEmbedPayload.self, from: data),
              !payload.title.isEmpty else {
            throw ImportError.invalidResponse
        }

        return MusicItem(
            source: link.source,
            url: link.url.absoluteString,
            title: payload.title,
            artworkURL: payload.thumbnailURL,
            embedURL: link.source == .soundCloud ? Self.soundCloudPlayerURL(in: payload.html)?.absoluteString : nil,
            authorName: payload.authorName
        )
    }
}
