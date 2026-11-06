import SwiftUI
import UniformTypeIdentifiers
import MediaPlayer
import AVKit

struct NowPlayingView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Environment(\.dismiss) private var dismiss
    @State private var lyrics: [LyricLine] = []
    @State private var lyricsMessage = "Find synced lyrics"
    @State private var isLoadingLyrics = false
    @State private var showingQueue = false
    @State private var showingLyrics = false
    @State private var showingCoverPicker = false
    @State private var coverAlert = false
    @State private var coverMessage = ""

    private var activeLine: Int {
        lyrics.lastIndex(where: { $0.time <= audioPlayer.currentTime }) ?? 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundGradient
                VStack(spacing: 0) {
                    artworkSection(height: min(geometry.size.height * 0.55, geometry.size.width * 1.30))
                    metadataSection
                        .padding(.horizontal, 26)
                        .padding(.top, 17)
                    progressSection
                        .padding(.horizontal, 28)
                        .padding(.top, 20)
                    transportControls
                        .padding(.horizontal, 42)
                        .padding(.top, 22)
                    volumeSection
                        .padding(.horizontal, 28)
                        .padding(.top, 22)
                    bottomActions
                        .padding(.horizontal, 54)
                        .padding(.top, 17)
                        .padding(.bottom, 10)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .foregroundStyle(.white)
            .ignoresSafeArea(edges: .top)
        }
        .task(id: audioPlayer.currentSong?.id) { await loadLyrics() }
        .sheet(isPresented: $showingQueue) { queueSheet }
        .sheet(isPresented: $showingLyrics) { lyricsSheet }
        .fileImporter(isPresented: $showingCoverPicker, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    do {
                        let filename = try MusicFileStore.storeAnimatedCover(from: url)
                        if let song = audioPlayer.currentSong {
                            if let oldName = AlbumCoverStore.filename(for: song) {
                                try? FileManager.default.removeItem(at: MusicFileStore.animatedCoverURL(for: oldName))
                            }
                            AlbumCoverStore.set(filename, for: song)
                        }
                    } catch {
                        coverMessage = error.localizedDescription
                        coverAlert = true
                    }
                }
            case .failure(let error):
                coverMessage = error.localizedDescription
                coverAlert = true
            }
        }
        .alert("Animated Cover", isPresented: $coverAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(coverMessage)
        }
        .alert("Playback", isPresented: Binding(get: { audioPlayer.playbackError != nil }, set: { if !$0 { audioPlayer.playbackError = nil } })) {
            Button("OK", role: .cancel) { audioPlayer.playbackError = nil }
        } message: {
            Text(audioPlayer.playbackError ?? "")
        }
    }

    private func artworkSection(height: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            Group {
                if let song = audioPlayer.currentSong,
                   let filename = AlbumCoverStore.filename(for: song) {
                    AnimatedCoverView(url: MusicFileStore.animatedCoverURL(for: filename))
                } else {
                    ArtworkView(data: audioPlayer.currentSong?.artworkData)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.48),
                    .init(color: .black.opacity(0.18), location: 0.72),
                    .init(color: .black.opacity(0.62), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(audioPlayer.currentSong?.displayTitle ?? "Nothing playing")
                        .font(AppFont.font(size: 25, weight: .bold))
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                    Text(audioPlayer.currentSong?.artist ?? "")
                        .font(AppFont.font(size: 19))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                }
                Spacer(minLength: 8)
                Menu {
                    Button {
                        showingCoverPicker = true
                    } label: {
                        Label("Upload Animated Cover", systemImage: "video.badge.plus")
                    }
                    if let song = audioPlayer.currentSong, AlbumCoverStore.filename(for: song) != nil {
                        Button(role: .destructive) {
                            removeAnimatedCover()
                        } label: {
                            Label("Remove Animated Cover", systemImage: "trash")
                        }
                    }
                    Button("Done") { dismiss() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 23, weight: .bold))
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More playback options")
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 22)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    private var metadataSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(audioPlayer.currentSong?.album.isEmpty == false ? audioPlayer.currentSong!.album : "LOCAL LIBRARY")
                    .font(AppFont.font(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Text(audioPlayer.isPlaying ? "NOW PLAYING" : "PAUSED")
                    .font(AppFont.font(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Button {
                showingQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 21, weight: .medium))
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Playing queue")
        }
    }

    private var progressSection: some View {
        VStack(spacing: 7) {
            Slider(
                value: Binding(
                    get: { audioPlayer.currentTime },
                    set: { audioPlayer.seek(to: $0) }
                ),
                in: 0...max(audioPlayer.duration, 1)
            )
            .tint(.white)
            HStack {
                Text(audioPlayer.currentTime.formattedTime)
                Spacer()
                Text("−\(max(0, audioPlayer.duration - audioPlayer.currentTime).formattedTime)")
            }
            .font(AppFont.font(size: 13).monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var transportControls: some View {
        HStack(alignment: .center) {
            Button { audioPlayer.skipToPrevious() } label: {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 31, weight: .medium))
                    .frame(width: 58, height: 62)
            }
            .accessibilityLabel("Previous track")

            Spacer()

            Button { audioPlayer.togglePlayback() } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .frame(width: 76, height: 68)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(audioPlayer.isPlaying ? "Pause" : "Play")

            Spacer()

            Button { audioPlayer.skipToNext() } label: {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 31, weight: .medium))
                    .frame(width: 58, height: 62)
            }
            .accessibilityLabel("Next track")
        }
        .buttonStyle(.plain)
    }

    private var volumeSection: some View {
        SystemVolumeSlider()
            .frame(height: 34)
            .tint(.white)
    }

    private var bottomActions: some View {
        HStack {
            Button { showingLyrics = true } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Lyrics")

            Spacer()

            AirPlayRouteButton()
                .frame(width: 42, height: 42)

            Spacer()

            Button { showingQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 23, weight: .medium))
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Playing queue")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white.opacity(0.82))
    }

    private var backgroundGradient: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [.black, .indigo.opacity(0.75), .purple.opacity(0.48), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if let data = audioPlayer.currentSong?.artworkData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .blur(radius: 85)
                        .opacity(0.48)
                        .overlay(.black.opacity(0.48))
                }
            }
            .ignoresSafeArea()
        }
    }

    private func removeAnimatedCover() {
        guard let song = audioPlayer.currentSong,
              let filename = AlbumCoverStore.remove(for: song) else { return }
        try? FileManager.default.removeItem(at: MusicFileStore.animatedCoverURL(for: filename))
    }

    private var queueSheet: some View {
        NavigationStack {
            List {
                Section("Now Playing") {
                    if let song = audioPlayer.currentSong {
                        HStack(spacing: 12) {
                            ArtworkView(data: song.artworkData)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading) {
                                Text(song.displayTitle).font(.headline)
                                Text(song.artist).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "waveform").foregroundStyle(.tint)
                        }
                    }
                }
                Section("Up Next · \(audioPlayer.upcomingSongs.count)") {
                    ForEach(Array(audioPlayer.upcomingSongs.enumerated()), id: \.element.id) { index, song in
                        HStack(spacing: 12) {
                            ArtworkView(data: song.artworkData)
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            VStack(alignment: .leading) {
                                Text(song.displayTitle).lineLimit(1)
                                Text(song.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(song.duration.formattedTime).font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { audioPlayer.play(song) }
                    }
                    .onDelete { offsets in
                        let base = audioPlayer.currentQueue.count - audioPlayer.upcomingSongs.count
                        for offset in offsets.sorted(by: >) {
                            audioPlayer.removeFromQueue(at: offset + base)
                        }
                    }
                    .onMove { source, destination in
                        let base = audioPlayer.currentQueue.count - audioPlayer.upcomingSongs.count
                        for offset in source {
                            audioPlayer.moveQueueItem(from: offset + base, to: destination + base)
                        }
                    }
                }
            }
            .navigationTitle("Playing Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingQueue = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var lyricsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Text("SYNCED LYRICS")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                        Spacer()
                        Button(isLoadingLyrics ? "Loading…" : "Refresh") {
                            Task { await loadLyrics() }
                        }
                        .font(.caption.weight(.semibold))
                        .disabled(isLoadingLyrics)
                    }
                    if lyrics.isEmpty {
                        Text(lyricsMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ForEach(Array(lyrics.enumerated()), id: \.element.id) { index, line in
                            Group {
                                if line.words.isEmpty {
                                    Text(line.text)
                                        .foregroundStyle(index == activeLine ? .primary : .secondary)
                                } else {
                                    line.words.reduce(Text("")) { partial, word in
                                        partial + Text(word.text)
                                            .foregroundColor(audioPlayer.currentTime >= word.time ? .primary : .secondary)
                                    }
                                }
                            }
                            .font(.system(size: index == activeLine ? 23 : 19, weight: index == activeLine ? .bold : .regular))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .onTapGesture { audioPlayer.seek(to: line.time) }
                        }
                    }
                }
                .padding(22)
            }
            .navigationTitle(audioPlayer.currentSong?.displayTitle ?? "Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingLyrics = false }
                }
            }
        }
        .preferredColorScheme(.dark)
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

private struct SystemVolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        view.showsVolumeSlider = true
        view.tintColor = .white
        view.setVolumeThumbImage(UIImage(systemName: "circle.fill"), for: .normal)
        return view
    }

    func updateUIView(_ view: MPVolumeView, context: Context) {
        view.tintColor = .white
    }
}

private struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(frame: .zero)
        view.tintColor = .white
        view.activeTintColor = .white
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {
        view.tintColor = .white
        view.activeTintColor = .white
    }
}
