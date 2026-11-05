import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]

    @State private var showingImporter = false
    @State private var importMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    ContentUnavailableView {
                        Label("Your library is empty", systemImage: "music.note")
                    } description: {
                        Text("Import MP3 files from the Files app to get started.")
                    } actions: {
                        Button("Import music", systemImage: "plus") {
                            showingImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        Section {
                            ForEach(songs) { song in
                                SongRow(song: song) {
                                    audioPlayer.play(song, from: songs)
                                }
                            }
                            .onDelete(perform: deleteSongs)
                        } header: {
                            HStack {
                                Text("YOUR MUSIC")
                                Spacer()
                                Text("\(songs.count) SONGS")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isImporting)
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.mp3],
                allowsMultipleSelection: true,
                onCompletion: handleImport
            )
            .alert("Import", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = error.localizedDescription
        case .success(let urls):
            isImporting = true
            Task {
                var importedCount = 0
                var failures: [String] = []

                for sourceURL in urls {
                    do {
                        let localURL = try MusicFileStore.importFile(from: sourceURL)
                        let metadata = try await MetadataReader.read(from: localURL)
                        let song = Song(
                            title: metadata.title,
                            artist: metadata.artist,
                            album: metadata.album,
                            duration: metadata.duration,
                            fileName: localURL.lastPathComponent,
                            artworkData: metadata.artworkData
                        )
                        modelContext.insert(song)
                        importedCount += 1
                    } catch {
                        failures.append("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }

                try? modelContext.save()
                isImporting = false

                if failures.isEmpty {
                    importMessage = "Imported \(importedCount) MP3 file(s)."
                } else {
                    importMessage = "Imported \(importedCount) file(s).\n\n" + failures.joined(separator: "\n")
                }
            }
        }
    }

    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let song = songs[index]
            let fileURL = MusicFileStore.musicDirectory.appendingPathComponent(song.fileName)
            try? FileManager.default.removeItem(at: fileURL)
            modelContext.delete(song)
        }
        try? modelContext.save()
    }
}
