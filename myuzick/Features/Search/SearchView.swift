import SwiftData
import SwiftUI

struct SearchView: View {
    @Query(sort: \Song.title) private var songs: [Song]
    @Environment(\.audioPlayerReference) private var audioPlayerReference
    private var audioPlayer: AudioPlayer { audioPlayerReference! }
    @State private var query = ""

    private var results: [Song] {
        guard !query.isEmpty else { return songs }
        return songs.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.artist.localizedCaseInsensitiveContains(query)
                || $0.album.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(results) { song in
                SongRow(song: song) {
                    audioPlayer.play(song, from: results)
                }
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: "Songs, artists, albums")
        }
    }
}
