import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @AppStorage("waveformHapticsEnabled") private var waveformHapticsEnabled = false
    @AppStorage("lastfmUsername") private var lastfmUsername = ""
    @AppStorage("lastfmAPIKey") private var lastfmAPIKey = ""
    @AppStorage("lastfmSharedSecret") private var lastfmSharedSecret = ""
    @AppStorage("lastfmSessionKey") private var lastfmSessionKey = ""
    @State private var showLastFMDetails = false
    @State private var showLastFMAlert = false
    @State private var lastFMMessage = ""
    @State private var isConnectingLastFM = false
    @AppStorage("lastfmPendingAuthToken") private var lastfmPendingAuthToken = ""
    @State private var showingFontPicker = false
    @State private var fontMessage: String?
    @AppStorage("myuzick.customFontPostScriptName") private var customFontName = ""

    private func connectLastFM() {
        isConnectingLastFM = true
        Task { @MainActor in
            defer { isConnectingLastFM = false }
            do {
                let url = try await LastFMScrobbler.requestAuthorization(apiKey: lastfmAPIKey, sharedSecret: lastfmSharedSecret)
                await UIApplication.shared.open(url)
                lastFMMessage = "Approve access on the Last.fm page. When you're done, return to myuzick and tap “I've approved access — finish login”."
                showLastFMAlert = true
            } catch {
                lastFMMessage = error.localizedDescription
                showLastFMAlert = true
            }
        }
    }

    private func finishLastFMLogin() {
        isConnectingLastFM = true
        Task { @MainActor in
            defer { isConnectingLastFM = false }
            do {
                let result = try await LastFMScrobbler.finishAuthorization(apiKey: lastfmAPIKey, sharedSecret: lastfmSharedSecret)
                lastfmUsername = result.username
                lastfmSessionKey = result.sessionKey
                lastfmPendingAuthToken = ""
                lastFMMessage = "Connected as \(result.username). Scrobbling is ready."
                showLastFMAlert = true
            } catch {
                lastFMMessage = error.localizedDescription
                showLastFMAlert = true
            }
        }
    }

    private let bands = ["60 Hz", "230 Hz", "910 Hz", "3.6 kHz", "14 kHz"]

    var body: some View {
        NavigationStack {
            List {
                Section("Equalizer") {
                    ForEach(bands.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(bands[index])
                                Spacer()
                                Text("\(Int(audioPlayer.eqGains[index])) dB")
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: Binding(
                                get: { Double(audioPlayer.eqGains[index]) },
                                set: { audioPlayer.setEQGain(Float($0), forBand: index) }
                            ), in: -12...12, step: 1)
                            .tint(.cyan)
                        }
                        .padding(.vertical, 3)
                    }
                    Button("Reset equalizer") { audioPlayer.resetEQ() }
                }

                Section("Appearance") {
                    LabeledContent("Interface font", value: customFontName.isEmpty ? "System" : customFontName)
                    Button("Upload TTF / OTF font") { showingFontPicker = true }
                    if !customFontName.isEmpty {
                        Button("Use system font", role: .destructive) { AppFont.remove(); customFontName = "" }
                    }
                    Text("The selected font is registered locally and used as the app default. Some system-provided controls retain their native typeface.")
                        .font(AppFont.font(size: 12))
                        .foregroundStyle(.secondary)
                }

                Section("Haptics") {
                    Toggle("Waveform haptics", isOn: $waveformHapticsEnabled)
                    Text("Uses audio intensity to trigger subtle haptic pulses while music plays. Availability depends on your iPhone's haptic hardware.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Last.fm scrobbling") {
                    if lastfmSessionKey.isEmpty {
                        TextField("Last.fm API key", text: $lastfmAPIKey)
                            .textInputAutocapitalization(.never)
                        SecureField("App shared secret", text: $lastfmSharedSecret)
                        Button(isConnectingLastFM ? "Connecting…" : "Connect Last.fm") { connectLastFM() }
                            .disabled(isConnectingLastFM || lastfmAPIKey.isEmpty || lastfmSharedSecret.isEmpty)
                        if !lastfmPendingAuthToken.isEmpty {
                            Button("I've approved access — finish login") { finishLastFMLogin() }
                                .disabled(isConnectingLastFM)
                        }
                    } else {
                        LabeledContent("Connected account", value: lastfmUsername)
                        Button("Disconnect Last.fm", role: .destructive) {
                            lastfmSessionKey = ""
                            lastfmUsername = ""
                            lastfmPendingAuthToken = ""
                        }
                    }
                    Button("How does login work?") { showLastFMDetails = true }
                    Text("Connect opens Last.fm in your browser. Approve myuzick, return here, then finish login. Your app API key and shared secret are required once; your Last.fm password is never entered into myuzick.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Library & playback") {
                    LabeledContent("Audio engine", value: "AVAudioEngine")
                    LabeledContent("Music storage", value: "On this iPhone")
                    LabeledContent("Supported formats", value: "MP3 · M4A · AAC · WAV · AIFF · FLAC · CAF")
                }

                Section {
                    LabeledContent("Version", value: "0.2.0")
                    LabeledContent("App", value: "myuzick")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Settings")
            .fileImporter(isPresented: $showingFontPicker, allowedContentTypes: [.font], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        do { try AppFont.install(from: url) }
                        catch { fontMessage = error.localizedDescription }
                    }
                case .failure(let error): fontMessage = error.localizedDescription
                }
            }
            .alert("Font", isPresented: Binding(get: { fontMessage != nil }, set: { if !$0 { fontMessage = nil } })) {
                Button("OK", role: .cancel) { fontMessage = nil }
            } message: { Text(fontMessage ?? "") }
            .alert("Last.fm", isPresented: $showLastFMAlert) { Button("OK", role: .cancel) { } } message: { Text(lastFMMessage) }
            .alert("Last.fm setup", isPresented: $showLastFMDetails) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create a Last.fm API application once to obtain an API key and shared secret. Tap Connect Last.fm, approve access in the browser, then return and finish login. myuzick obtains and stores the session key automatically. Scrobbling starts after at least half the track has played, up to the four-minute threshold.")
            }
        }
    }
}
