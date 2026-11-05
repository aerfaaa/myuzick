import SwiftUI

struct MiniPlayer: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var showingNowPlaying = false

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(data: audioPlayer.currentSong?.artworkData)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Button {
                showingNowPlaying = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(audioPlayer.currentSong?.displayTitle ?? "")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(audioPlayer.currentSong?.artist ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                audioPlayer.togglePlayback()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 38, height: 42)
            }
            .buttonStyle(.plain)

            Button {
                audioPlayer.skipToNext()
            } label: {
                Image(systemName: "forward.end.fill")
                    .font(.title3)
                    .frame(width: 32, height: 42)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        }
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .environmentObject(audioPlayer)
        }
    }
}
