import SwiftUI\nimport UniformTypeIdentifiers\nimport UIKit

struct SettingsView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @AppStorage("waveformHapticsEnabled") private var waveformHapticsEnabled = false
    @AppStorage("lastfmUsername") private var lastfmUsername = ""
    @AppStorage("lastfmAPIKey") private var lastfmAPIKey = ""
    @AppStorage("lastfmSharedSecret") private var lastfmSharedSecret = ""
    @AppStorage("lastfmSessionKey") private var lastfmSessionKey = ""
    @State private var showLastFMDetails = false\n    @State private var showLastFMAlert = false\n    @State private var lastFMMessage = ""\n    @State private var isConnectingLastFM = false\n    @AppStorage("lastfmPendingAuthToken") private var lastfmPendingAuthToken = ""\n    @State private var showingFontPicker = false\n    @State private var fontMessage: String?\n    @AppStorage("myuzick.customFontPostScriptName") private var customFontName = ""

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

                Section("Appearance") {\n                    LabeledContent("Interface font", value: customFontName.isEmpty ? "System" : customFontName)\n                    Button("Upload TTF / OTF font") { showingFontPicker = true }\n                    if !customFontName.isEmpty {\n                        Button("Use system font", role: .destructive) { AppFont.remove(); customFontName = "" }\n                    }\n                    Text("The selected font is registered locally and used as the app default. Some system-provided controls retain their native typeface.")\n                        .font(.caption)\n                        .foregroundStyle(.secondary)\n                }\n\n                Section("Haptics") {
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
                    LabeledContent("Supported format", value: "MP3")
                }

                Section {
                    LabeledContent("Version", value: "0.2.0")
                    LabeledContent("App", value: "myuzick")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Settings")\n            .fileImporter(isPresented: $showingFontPicker, allowedContentTypes: [.font], allowsMultipleSelection: false) { result in\n                switch result {\n                case .success(let urls):\n                    if let url = urls.first {\n                        do { try AppFont.install(from: url) }\n                        catch { fontMessage = error.localizedDescription }\n                    }\n                case .failure(let error): fontMessage = error.localizedDescription\n                }\n            }\n            .alert("Font", isPresented: Binding(get: { fontMessage != nil }, set: { if !$0 { fontMessage = nil } })) {\n                Button("OK", role: .cancel) { fontMessage = nil }\n            } message: { Text(fontMessage ?? "") }
            .alert("Last.fm", isPresented: $showLastFMAlert) { Button("OK", role: .cancel) { } } message: { Text(lastFMMessage) }\n            .alert("Last.fm setup", isPresented: $showLastFMDetails) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create a Last.fm API application once to obtain an API key and shared secret. Tap Connect Last.fm, approve access in the browser, then return and finish login. myuzick obtains and stores the session key automatically. Scrobbling starts after at least half the track has played, up to the four-minute threshold.")
            }
        }
    }
}
