import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var currentSong: Song?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var playbackError: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var queue: [Song] = []
    private var currentIndex: Int = 0

    init() {
        configureAudioSession()
    }

    deinit {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
    }

    func play(_ song: Song, from songs: [Song]? = nil) {
        if let songs {
            queue = songs
            currentIndex = songs.firstIndex(where: { $0.id == song.id }) ?? 0
        } else if queue.isEmpty || !queue.contains(where: { $0.id == song.id }) {
            queue = [song]
            currentIndex = 0
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == song.id }) ?? 0
        }
        loadCurrentSong()
    }

    func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to seconds: Double) {
        let safeTime = max(0, min(seconds, duration))
        player?.seek(to: CMTime(seconds: safeTime, preferredTimescale: 600))
        currentTime = safeTime
    }

    func skipToNext() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        loadCurrentSong()
    }

    func skipToPrevious() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
            loadCurrentSong()
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            playbackError = "Couldn't configure audio playback: \(error.localizedDescription)"
        }
    }

    private func loadCurrentSong() {
        guard queue.indices.contains(currentIndex) else { return }
        let song = queue[currentIndex]
        let url = MusicFileStore.musicDirectory.appendingPathComponent(song.fileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            playbackError = "The audio file for “\(song.displayTitle)” could not be found."
            isPlaying = false
            return
        }

        currentSong = song
        currentTime = 0
        duration = song.duration

        let item = AVPlayerItem(url: url)
        player?.pause()
        player = AVPlayer(playerItem: item)
        installTimeObserver()
        player?.play()
        isPlaying = true
        playbackError = nil

        Task {
            let assetDuration = try? await item.asset.load(.duration)
            if let seconds = assetDuration?.seconds, seconds.isFinite, seconds > 0 {
                duration = seconds
            }
        }
    }

    private func installTimeObserver() {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }

        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let itemDuration = self.player?.currentItem?.duration.seconds,
                   itemDuration.isFinite, itemDuration > 0 {
                    self.duration = itemDuration
                }
            }
        }
    }
}
