import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @AppStorage("waveformHapticsEnabled") private var waveformHapticsEnabled = false
    @AppStorage("lastfmUsername") private var lastfmUsername = ""
    @AppStorage("lastfmAPIKey") private var lastfmAPIKey = ""
    @AppStorage("lastfmSharedSecret") private var lastfmSharedSecret = ""
    @AppStorage("lastfmSessionKey") private var lastfmSessionKey = ""
    @State private var showLastFMDetails = false

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

                Section("Haptics") {
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
            .navigationTitle("Settings")
            .alert("Last.fm setup", isPresented: $showLastFMDetails) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Create an API application in your Last.fm account to get an API key and shared secret. A valid session key is also required. Once all three credentials are entered, myuzick submits a scrobble after at least half the track has played (up to the four-minute threshold). You must obtain the session key through Last.fm account authorization.")
            }
        }
    }
}
