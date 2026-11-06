import SwiftUI

struct MiniPlayer: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @State private var showingNowPlaying = false

    var body: some View {
        Group {
            if audioPlayer.currentSong != nil {
                playerBar
            }
        }
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView()
                .environmentObject(audioPlayer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var playerBar: some View {
        HStack(spacing: 12) {
            ArtworkView(data: audioPlayer.currentSong?.artworkData)
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                showingNowPlaying = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(audioPlayer.currentSong?.displayTitle ?? "")
                        .font(AppFont.font(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(audioPlayer.currentSong?.artist ?? "")
                        .font(AppFont.font(size: 12))
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.16))
        }
    }
}
