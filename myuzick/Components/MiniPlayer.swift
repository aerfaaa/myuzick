import SwiftUI

struct MiniPlayer: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var showingNowPlaying = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: audioPlayer.currentSong?.artworkData)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                audioPlayer.skipToPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.subheadline)
                    .frame(width: 32, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            Button {
                audioPlayer.togglePlayback()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .frame(width: 34, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.08))
        }
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .environmentObject(audioPlayer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
