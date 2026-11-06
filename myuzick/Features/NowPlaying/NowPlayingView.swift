import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var lyrics: [LyricLine] = []
    @State private var lyricsMessage = "Find synced lyrics"
    @State private var isLoadingLyrics = false
    @State private var animateArtwork = false

    private var activeLine: Int {
        lyrics.lastIndex(where: { $0.time <= audioPlayer.currentTime }) ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                ScrollView {
                    VStack(spacing: 25) {
                        ArtworkView(data: audioPlayer.currentSong?.artworkData)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: 330)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: .black.opacity(0.35), radius: 28, y: 16)
                            .padding(.horizontal, 30)
                        VStack(spacing: 7) {
                            Text(audioPlayer.currentSong?.displayTitle ?? "Nothing playing")
                                .font(.title2.weight(.bold)).lineLimit(1)
                            Text(audioPlayer.currentSong?.artist ?? "")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.68))
                        }
                        .padding(.horizontal, 24)
                        playbackControls
                        lyricsPanel
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 35)
                }
            }
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("NOW PLAYING").font(.caption.weight(.bold)).tracking(2)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task(id: audioPlayer.currentSong?.id) { await loadLyrics() }
            .alert("Playback", isPresented: Binding(get: { audioPlayer.playbackError != nil }, set: { if !$0 { audioPlayer.playbackError = nil } })) {
                Button("OK", role: .cancel) { audioPlayer.playbackError = nil }
            } message: { Text(audioPlayer.playbackError ?? "") }
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(colors: [.black, .indigo.opacity(0.75), .purple.opacity(0.55), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let data = audioPlayer.currentSong?.artworkData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().blur(radius: 85).opacity(0.38).scaleEffect(animateArtwork ? 1.2 : 1.04).overlay(.black.opacity(0.52)).animation(.easeInOut(duration: 9).repeatForever(autoreverses: true), value: animateArtwork)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: audioPlayer.currentSong?.id)
        .onAppear { animateArtwork = true }
    }

    private var playbackControls: some View {
        VStack(spacing: 10) {
            Slider(value: Binding(get: { audioPlayer.currentTime }, set: { audioPlayer.seek(to: $0) }), in: 0...max(audioPlayer.duration, 1)).tint(.white)
            HStack {
                Text(audioPlayer.currentTime.formattedTime)
                Spacer()
                Text(max(0, audioPlayer.duration - audioPlayer.currentTime).formattedTime)
            }
            .font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.65))
            HStack(spacing: 42) {
                Button { audioPlayer.skipToPrevious() } label: { Image(systemName: "backward.end.fill").font(.title2) }
                Button { audioPlayer.togglePlayback() } label: {
                    Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .semibold)).foregroundStyle(.black)
                        .frame(width: 72, height: 72).background(.white, in: Circle())
                }
                Button { audioPlayer.skipToNext() } label: { Image(systemName: "forward.end.fill").font(.title2) }
            }
            .buttonStyle(.plain).padding(.top, 5)
        }
        .padding(.horizontal, 28)
    }

    private var lyricsPanel: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LYRICS").font(.caption.weight(.bold)).tracking(2)
                Spacer()
                Button(isLoadingLyrics ? "Loading…" : "Refresh") { Task { await loadLyrics() } }
                    .font(.caption.weight(.semibold)).disabled(isLoadingLyrics)
            }
            if lyrics.isEmpty {
                Text(lyricsMessage).font(.subheadline).foregroundStyle(.white.opacity(0.65)).frame(maxWidth: .infinity, minHeight: 70)
            } else {
                ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                    Group {
                        if line.words.isEmpty {
                            Text(line.text)
                                .foregroundStyle(index == activeLine ? .white : .white.opacity(0.35))
                        } else {
                            line.words.reduce(Text("")) { partial, word in
                                partial + Text(word.text).foregroundColor(audioPlayer.currentTime >= word.time ? .white : .white.opacity(0.38))
                            }
                        }
                    }
                    .font(index == activeLine ? .title3.weight(.bold) : .body)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .onTapGesture { audioPlayer.seek(to: line.time) }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.12)))
        .padding(.horizontal, 18)
    }

    @MainActor
    private func loadLyrics() async {
        guard let song = audioPlayer.currentSong else { return }
        isLoadingLyrics = true
        lyricsMessage = "Searching local and online lyrics…"
        do {
            lyrics = try await LyricsService.fetch(for: song)
            lyricsMessage = lyrics.isEmpty ? "No synced lyrics found." : ""
        } catch {
            lyrics = []
            lyricsMessage = error.localizedDescription
        }
        isLoadingLyrics = false
    }
}
