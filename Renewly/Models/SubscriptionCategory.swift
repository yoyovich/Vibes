import SwiftUI

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case streaming
    case music
    case software
    case cloud
    case gaming
    case fitness
    case news
    case education
    case utilities
    case other

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .streaming: "Streaming"
        case .music: "Music"
        case .software: "Software"
        case .cloud: "Cloud"
        case .gaming: "Gaming"
        case .fitness: "Fitness"
        case .news: "News"
        case .education: "Education"
        case .utilities: "Utilities"
        case .other: "Other"
        }
    }

    var localizedTitle: String { String(localized: title) }

    var symbolName: String {
        switch self {
        case .streaming: "play.tv"
        case .music: "music.note"
        case .software: "app.badge"
        case .cloud: "icloud"
        case .gaming: "gamecontroller"
        case .fitness: "figure.run"
        case .news: "newspaper"
        case .education: "graduationcap"
        case .utilities: "wrench.and.screwdriver"
        case .other: "square.grid.2x2"
        }
    }

    /// System colors adapt automatically to light and dark appearance.
    var color: Color {
        switch self {
        case .streaming: .red
        case .music: .pink
        case .software: .blue
        case .cloud: .cyan
        case .gaming: .purple
        case .fitness: .green
        case .news: .orange
        case .education: .indigo
        case .utilities: .brown
        case .other: .gray
        }
    }
}
