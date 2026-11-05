import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Playback") {
                    LabeledContent("Audio engine", value: "AVPlayer")
                    LabeledContent("Playback mode", value: "Offline")
                }

                Section("Library") {
                    LabeledContent("Supported format", value: "MP3")
                    LabeledContent("Storage", value: "On this iPhone")
                }

                Section {
                    LabeledContent("Version", value: "0.1.0")
                    LabeledContent("App", value: "myuzick")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
