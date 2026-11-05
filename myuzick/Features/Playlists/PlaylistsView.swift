import SwiftUI

struct PlaylistsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Playlists are coming",
                systemImage: "music.note.list",
                description: Text("Create your own collections in a future myuzick update.")
            )
            .navigationTitle("Playlists")
        }
    }
}
