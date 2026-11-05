import SwiftUI

struct RootView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "square.stack") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            PlaylistsView()
                .tabItem { Label("Playlists", systemImage: "music.note.list") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
        .tint(.white)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if audioPlayer.currentSong != nil {
                MiniPlayer()
                    .environmentObject(audioPlayer)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
    }
}
