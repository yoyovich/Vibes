import SwiftUI
import AVFAudio

@main
struct VibesApp: App {
    @StateObject private var library = LibraryStore()

    init() {
        // Allows the web player to request audio when the app is in the foreground.
        // Background behavior is controlled by the embedded service and is not guaranteed.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
        }
    }
}
