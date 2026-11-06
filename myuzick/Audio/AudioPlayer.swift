import AVFoundation
import Combine
import CoreHaptics
import MediaPlayer
import Foundation
import UIKit

@MainActor
final class AudioPlayer: ObservableObject {
    @Published private(set) var currentSong: Song?
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var waveformLevel: Double = 0
    @Published private(set) var eqGains: [Float] = [0, 0, 0, 0, 0]
    @Published private(set) var isShuffling = false
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var queueRevision = 0
    @Published var playbackError: String?

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: 5)
    private var audioFile: AVAudioFile?
    private var originalFolderAccess: (url: URL, accessed: Bool)?
    private var queue: [Song] = []
    private var originalQueue: [Song] = []
    private var currentIndex = 0
    private var timer: Timer?
    private var hapticEngine: CHHapticEngine?
    private var lastHapticTime: TimeInterval = 0
    private var scrobbledSongID: UUID?
    private var trackStartTimestamp = Date().timeIntervalSince1970
    private var playbackStartOffset: Double = 0
    private var isAtEnd = false
    private let frequencies: [Float] = [60, 230, 910, 3600, 14000]

    init() {
        configureAudioSession()
        configureAudioGraph()
        configureHaptics()
        configureRemoteCommands()
    }

    func setEQGain(_ gain: Float, forBand index: Int) {
        guard equalizer.bands.indices.contains(index) else { return }
        let safeGain = max(-12, min(12, gain))
        equalizer.bands[index].gain = safeGain
        eqGains[index] = safeGain
        UserDefaults.standard.set(safeGain, forKey: "eqGain_\(index)")
    }

    func resetEQ() {
        equalizer.bands.enumerated().forEach { index, band in
            band.gain = 0
            eqGains[index] = 0
            UserDefaults.standard.set(Float(0), forKey: "eqGain_\(index)")
        }
    }

    var upcomingSongs: [Song] {
        guard !queue.isEmpty else { return [] }
        return Array(queue.dropFirst(min(currentIndex + 1, queue.count)))
    }

    var currentQueue: [Song] { queue }

    func setShuffle(_ enabled: Bool) {
        guard isShuffling != enabled else { return }
        isShuffling = enabled
        guard currentSong != nil else { return }
        let played = Array(queue.prefix(currentIndex + 1))
        if enabled {
            originalQueue = queue
            queue = played + queue.dropFirst(currentIndex + 1).shuffled()
        } else {
            let playedIDs = Set(played.map(\.id))
            let restored = originalQueue.filter { !playedIDs.contains($0.id) }
            queue = played + restored
        }
        queueRevision += 1
    }

    func cycleRepeatMode() { repeatMode = repeatMode.next }

    func addToQueue(_ song: Song) {
        queue.append(song)
        queueRevision += 1
    }

    func playNext(_ song: Song) {
        queue.insert(song, at: min(currentIndex + 1, queue.count))
        queueRevision += 1
    }

    func removeFromQueue(at index: Int) {
        guard queue.indices.contains(index), index != currentIndex else { return }
        queue.remove(at: index)
        if index < currentIndex { currentIndex -= 1 }
        queueRevision += 1
    }

    func moveQueueItem(from source: Int, to destination: Int) {
        guard queue.indices.contains(source), queue.indices.contains(destination), source != currentIndex else { return }
        let item = queue.remove(at: source)
        let adjusted = source < destination ? destination - 1 : destination
        queue.insert(item, at: max(currentIndex + 1, min(adjusted, queue.count)))
        queueRevision += 1
    }

    func play(_ song: Song, from songs: [Song]? = nil) {
        if let songs {
            originalQueue = songs
            queue = songs
            currentIndex = songs.firstIndex(where: { $0.id == song.id }) ?? 0
            if isShuffling {
                let played = Array(queue.prefix(currentIndex + 1))
                queue = played + queue.dropFirst(currentIndex + 1).shuffled()
            }
        } else if queue.isEmpty || !queue.contains(where: { $0.id == song.id }) {
            queue = [song]
            originalQueue = [song]
            currentIndex = 0
        } else {
            currentIndex = queue.firstIndex(where: { $0.id == song.id }) ?? 0
        }
        queueRevision += 1
        loadCurrentSong()
    }

    func togglePlayback() {
        if isPlaying {
            playerNode.pause()
            isPlaying = false
            stopTimer()
            updateNowPlaying()
        } else if audioFile != nil {
            if isAtEnd {
                playerNode.stop()
                scheduleAudio(from: 0)
                currentTime = 0
            }
            playerNode.play()
            isPlaying = true
            startTimer()
            updateNowPlaying()
        }
    }

    func seek(to seconds: Double) {
        guard audioFile != nil else { return }
        let wasPlaying = isPlaying
        playerNode.stop()
        currentTime = max(0, min(seconds, duration))
        scheduleAudio(from: currentTime)
        if wasPlaying { playerNode.play() }
        updateNowPlaying()
    }

    func skipToNext() {
        guard currentIndex + 1 < queue.count else {
            if repeatMode == .all, !queue.isEmpty { currentIndex = 0; loadCurrentSong() }
            return
        }
        currentIndex += 1
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
        playerNode.stop()
        stopTimer()
        currentSong = nil
        audioFile = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        queue = []
        originalQueue = []
        currentIndex = 0
        if let access = originalFolderAccess, access.accessed { access.url.stopAccessingSecurityScopedResource() }
        originalFolderAccess = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            playbackError = "Couldn't configure audio playback: \(error.localizedDescription)"
        }
    }

    private func configureAudioGraph() {
        for (index, band) in equalizer.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = frequencies[index]
            band.bandwidth = 1.0
            band.gain = UserDefaults.standard.object(forKey: "eqGain_\(index)") as? Float ?? 0
            eqGains[index] = band.gain
            band.bypass = false
        }
        engine.attach(playerNode)
        engine.attach(equalizer)
        engine.connect(playerNode, to: equalizer, format: nil)
        engine.connect(equalizer, to: engine.mainMixerNode, format: nil)
        playerNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            guard count > 0 else { return }
            var sum: Float = 0
            for index in 0..<count { sum += channel[index] * channel[index] }
            let rms = sqrt(sum / Float(count))
            let level = min(1, Double(rms) * 4)
            Task { @MainActor in self?.receiveWaveformLevel(level) }
        }
        do { try engine.start() } catch {
            playbackError = "Audio engine couldn't start: \(error.localizedDescription)"
        }
    }

    private func loadCurrentSong() {
        guard queue.indices.contains(currentIndex) else { return }
        let song = queue[currentIndex]
        if let previous = originalFolderAccess, previous.accessed { previous.url.stopAccessingSecurityScopedResource() }
        originalFolderAccess = nil
        if MusicFileStore.isLinked(song.fileName) {
            originalFolderAccess = MusicFileStore.startOriginalFolderAccess()
        }
        let url = MusicFileStore.resolve(song.fileName, in: originalFolderAccess?.url)
        do {
            let file = try AVAudioFile(forReading: url)
            playerNode.stop()
            audioFile = file
            currentSong = song
            currentTime = 0
            isAtEnd = false
            trackStartTimestamp = Date().timeIntervalSince1970
            scrobbledSongID = nil
            duration = Double(file.length) / file.processingFormat.sampleRate
            if !engine.isRunning { try engine.start() }
            scheduleAudio(from: 0)
            playerNode.play()
            isPlaying = true
            startTimer()
            updateNowPlaying()
            playbackError = nil
        } catch {
            playbackError = "Couldn't play “\(song.displayTitle)”: \(error.localizedDescription)"
            isPlaying = false
        }
    }

    private func scheduleAudio(from seconds: Double) {
        guard let file = audioFile else { return }
        playbackStartOffset = max(0, seconds)
        isAtEnd = false
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, seconds) * sampleRate)
        let remaining = AVAudioFrameCount(max(0, file.length - startFrame))
        guard remaining > 0 else {
            currentTime = 0
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor in self?.trackFinished() }
            }
            return
        }
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: remaining, at: nil) { [weak self] in
            Task { @MainActor in self?.trackFinished() }
        }
    }

    private func trackFinished() {
        guard isPlaying else { return }
        if repeatMode == .one {
            loadCurrentSong()
        } else if currentIndex + 1 < queue.count {
            currentIndex += 1
            loadCurrentSong()
        } else if repeatMode == .all, !queue.isEmpty {
            currentIndex = 0
            loadCurrentSong()
        } else {
            isPlaying = false
            isAtEnd = true
            currentTime = duration
            stopTimer()
            updateNowPlaying()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isPlaying, let nodeTime = self.playerNode.lastRenderTime,
                      let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
                let elapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
                self.currentTime = min(self.duration, max(0, self.playbackStartOffset + elapsed))
                self.updateNowPlaying()
                self.submitScrobbleIfDue()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateNowPlaying() {
        guard let song = currentSong else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.displayTitle,
            MPMediaItemPropertyArtist: song.artist,
            MPMediaItemPropertyAlbumTitle: song.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let data = song.artworkData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayback() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in if self?.isPlaying == true { self?.togglePlayback() } }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.skipToPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: event.positionTime) }
            return .success
        }
    }

    private func submitScrobbleIfDue() {
        guard let song = currentSong,
              song.duration >= 30,
              scrobbledSongID != song.id,
              currentTime >= min(song.duration / 2, 240),
              let apiKey = UserDefaults.standard.string(forKey: "lastfmAPIKey"), !apiKey.isEmpty,
              let secret = UserDefaults.standard.string(forKey: "lastfmSharedSecret"), !secret.isEmpty,
              let session = UserDefaults.standard.string(forKey: "lastfmSessionKey"), !session.isEmpty else { return }
        scrobbledSongID = song.id
        Task {
            do {
                try await LastFMScrobbler.scrobble(
                    song: song,
                    timestamp: Int(trackStartTimestamp),
                    apiKey: apiKey,
                    sharedSecret: secret,
                    sessionKey: session
                )
            } catch {
                playbackError = "Last.fm scrobble failed: \\(error.localizedDescription)"
            }
        }
    }

    private func configureHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch { hapticEngine = nil }
    }

    private func receiveWaveformLevel(_ level: Double) {
        waveformLevel = level
        guard UserDefaults.standard.bool(forKey: "waveformHapticsEnabled"),
              level > 0.22, let hapticEngine else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastHapticTime > 0.12 else { return }
        lastHapticTime = now
        let intensity = Float(min(1, max(0.15, level)))
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
        ], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try hapticEngine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch { }
    }
}
\n\nenum RepeatMode: String, CaseIterable {\n    case off, all, one\n    var next: RepeatMode {\n        switch self { case .off: return .all; case .all: return .one; case .one: return .off }\n    }\n}\n

enum RepeatMode: String, CaseIterable {
    case off, all, one
    var next: RepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}
