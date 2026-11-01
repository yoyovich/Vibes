import SwiftUI

@main
struct VibesApp: App {
    @StateObject private var library = LibraryStore()
    @StateObject private var playback = PlaybackStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(playback)
                .onChange(of: scenePhase) { _, value in
                    if value == .active { playback.engine.synchronize() }
                }
                .onAppear {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--soundcloud-smoke") {
                        var item = MusicItem(source: .soundCloud,
                            url: "https://soundcloud.com/forss/flickermood",
                            title: "Flickermood", artworkURL: nil, authorName: "Forss")
                        item.id = UUID(uuidString: "5CE96F2B-43AA-44EA-8B9A-ECE76BA055E6")!
                        library.add(item)
                    }
                    #endif
                }
        }
    }
}
