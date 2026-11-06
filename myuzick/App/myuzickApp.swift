import SwiftUI
import SwiftData

@main
struct myuzickApp: App {
    init() { AppFont.registerSavedFont() }
    @StateObject private var audioPlayer = AudioPlayer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(audioPlayer)
                .preferredColorScheme(.dark)
        }
        .modelContainer(for: [Song.self, Playlist.self])
    }
}
