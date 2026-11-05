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
    private var observedPlayer: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var queue: [Song] = []
    private var currentIndex = 0

    init() {
        configureAudioSession()
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
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                player.play()
                isPlaying = true
            } catch {
                playbackError = "Couldn't resume playback: \(error.localizedDescription)"
            }
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

    func stop() {
        player?.pause()
        removeObservers()
        player = nil
        currentSong = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        queue = []
        currentIndex = 0
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
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
            playbackError = "The audio file for “\(song.displayTitle)” couldn't be found."
            isPlaying = false
            return
        }

        removeObservers()
        currentSong = song
        currentTime = 0
        duration = song.duration

        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        installTimeObserver(on: newPlayer)
        installEndObserver(for: item)
        newPlayer.play()
        isPlaying = true
        playbackError = nil
    }

    private func installTimeObserver(on player: AVPlayer) {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        observedPlayer = player
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            Task { @MainActor in
                self.currentTime = time.seconds.isFinite ? time.seconds : 0
                if let seconds = self.player?.currentItem?.duration.seconds,
                   seconds.isFinite, seconds > 0 {
                    self.duration = seconds
                }
            }
        }
    }

    private func installEndObserver(for item: AVPlayerItem) {
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.currentIndex + 1 < self.queue.count {
                    self.currentIndex += 1
                    self.loadCurrentSong()
                } else {
                    self.isPlaying = false
                    self.currentTime = self.duration
                }
            }
        }
    }

    private func removeObservers() {
        if let timeObserver, let observedPlayer {
            observedPlayer.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        observedPlayer = nil

        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }
}
