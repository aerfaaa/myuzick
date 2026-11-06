import SwiftData
import SwiftUI\nimport UniformTypeIdentifiers

struct MetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let song: Song

    @State private var title: String
    @State private var artist: String
    @State private var album: String\n    @State private var artworkData: Data?\n    @State private var showingArtworkPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(song: Song) {
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)\n        _artworkData = State(initialValue: song.artworkData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Album artwork") {\n                    HStack(spacing: 14) {\n                        ArtworkView(data: artworkData).frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 10))\n                        Button("Choose artwork") { showingArtworkPicker = true }\n                    }\n                }\n                Section("Track information") {
                    TextField("Title", text: $title)
                    TextField("Artist", text: $artist)
                    TextField("Album", text: $album)
                }
                Section {
                    Text("Changes are written into the original audio file's embedded tags, not just myuzick's library database.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Edit Metadata")\n            .fileImporter(isPresented: $showingArtworkPicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in\n                if case .success(let urls) = result, let url = urls.first {\n                    let access = url.startAccessingSecurityScopedResource()\n                    defer { if access { url.stopAccessingSecurityScopedResource() } }\n                    artworkData = try? Data(contentsOf: url)\n                }\n            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Couldn't update file", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() {
        isSaving = true
        Task { @MainActor in
            let access = MusicFileStore.isLinked(song.fileName) ? MusicFileStore.startOriginalFolderAccess() : nil
            defer {
                if let access, access.accessed { access.url.stopAccessingSecurityScopedResource() }
                isSaving = false
            }
            if MusicFileStore.isLinked(song.fileName) && access == nil {
                errorMessage = "myuzick no longer has permission to access the linked folder. Relink it in your library."
                return
            }
            do {
                let fileURL = MusicFileStore.resolve(song.fileName, in: access?.url)
                try MetadataWriter.update(
                    fileURL: fileURL,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
                    album: album.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                song.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                song.artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
                song.album = album.trimmingCharacters(in: .whitespacesAndNewlines)\n                song.artworkData = artworkData
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
