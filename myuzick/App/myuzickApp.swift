import SwiftUI
import SwiftData

@main
struct myuzickApp: App {
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
