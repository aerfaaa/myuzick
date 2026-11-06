import SwiftData
import SwiftUI

struct MetadataEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let song: Song

    @State private var title: String
    @State private var artist: String
    @State private var album: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(song: Song) {
        self.song = song
        _title = State(initialValue: song.title)
        _artist = State(initialValue: song.artist)
        _album = State(initialValue: song.album)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Track information") {
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
            .navigationTitle("Edit Metadata")
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
                song.album = album.trimmingCharacters(in: .whitespacesAndNewlines)
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
