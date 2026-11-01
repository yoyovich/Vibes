import Foundation

struct MusicItem: Identifiable, Hashable, Codable {
    var id: UUID
    let source: MusicSource
    let url: String
    let title: String
    let artworkURL: String?
    let embedURL: String?
    let addedAt: Date

    init(source: MusicSource, url: String, title: String, artworkURL: String?, embedURL: String? = nil) {
        self.id = UUID()
        self.source = source
        self.url = url
        self.title = title
        self.artworkURL = artworkURL
        self.embedURL = embedURL
        self.addedAt = Date()
    }

    var mediaLink: MediaLink? { MediaLink.parse(url) }
}
