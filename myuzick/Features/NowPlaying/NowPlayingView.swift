import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                ArtworkView(data: audioPlayer.currentSong?.artworkData)
                    .frame(maxWidth: 340)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
                    .padding(.horizontal, 28)

                VStack(spacing: 6) {
                    Text(audioPlayer.currentSong?.displayTitle ?? "Nothing playing")
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                    Text(audioPlayer.currentSong?.artist ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.horizontal)

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { audioPlayer.currentTime },
                            set: { audioPlayer.seek(to: $0) }
                        ),
                        in: 0...max(audioPlayer.duration, 1)
                    )
                    HStack {
                        Text(audioPlayer.currentTime.formattedTime)
                        Spacer()
                        Text(max(0, audioPlayer.duration - audioPlayer.currentTime).formattedTime)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 28)

                HStack(spacing: 44) {
                    Button { audioPlayer.skipToPrevious() } label: {
                        Image(systemName: "backward.end.fill").font(.title2)
                    }
                    Button { audioPlayer.togglePlayback() } label: {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .frame(width: 76, height: 76)
                            .background(.white, in: Circle())
                            .foregroundStyle(.black)
                    }
                    Button { audioPlayer.skipToNext() } label: {
                        Image(systemName: "forward.end.fill").font(.title2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 12)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Playback", isPresented: Binding(
                get: { audioPlayer.playbackError != nil },
                set: { if !$0 { audioPlayer.playbackError = nil } }
            )) {
                Button("OK", role: .cancel) { audioPlayer.playbackError = nil }
            } message: {
                Text(audioPlayer.playbackError ?? "")
            }
        }
    }
}
