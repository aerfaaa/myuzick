import SwiftUI\nimport UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @AppStorage("waveformHapticsEnabled") private var waveformHapticsEnabled = false
    @AppStorage("lastfmUsername") private var lastfmUsername = ""
    @AppStorage("lastfmAPIKey") private var lastfmAPIKey = ""
    @AppStorage("lastfmSharedSecret") private var lastfmSharedSecret = ""
    @AppStorage("lastfmSessionKey") private var lastfmSessionKey = ""
    @State private var showLastFMDetails = false\n    @State private var showingFontPicker = false\n    @State private var fontMessage: String?\n    @AppStorage("myuzick.customFontPostScriptName") private var customFontName = ""

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
                    TextField("Last.fm username", text: $lastfmUsername)
                        .textInputAutocapitalization(.never)
                    SecureField("API key", text: $lastfmAPIKey)
                    SecureField("Shared secret", text: $lastfmSharedSecret)
                    SecureField("Session key", text: $lastfmSessionKey)
                    Button("How do I get these?") { showLastFMDetails = true }
                    Text("Scrobbling stays off until all credentials are supplied. Never share your Last.fm credentials with anyone.")
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
            .alert("Last.fm setup", isPresented: $showLastFMDetails) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create an API application in your Last.fm account to get an API key and shared secret. A valid session key is also required. Once all three credentials are entered, myuzick submits a scrobble after at least half the track has played (up to the four-minute threshold). You must obtain the session key through Last.fm account authorization.")
            }
        }
    }
}
