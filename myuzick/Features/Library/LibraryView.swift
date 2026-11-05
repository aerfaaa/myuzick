import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Query(sort: \\Song.dateAdded, order: .reverse) private var songs: [Song]

    @State private var showingImporter = false
    @State private var searchText = ""
    @State private var importMessage: String?
    @State private var isImporting = false

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return songs }
        return songs.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
                || $0.album.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    emptyLibrary
                } else {
                    songList
                }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("myuzick")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                    .accessibilityLabel("Import MP3 files")
                    .disabled(isImporting)
                }
            }
            .searchable(text: $searchText, prompt: "Search your music")
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.mp3],
                allowsMultipleSelection: true,
                onCompletion: handleImport
            )
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if audioPlayer.currentSong != nil {
                    MiniPlayer()
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("myuzick", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .overlay {
                if isImporting {
                    ProgressView("Importing music…")
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("Your music belongs here", systemImage: "music.note")
        } description: {
            Text("Import MP3 files from the Files app to start listening offline.")
        } actions: {
            Button {
                showingImporter = true
            } label: {
                Label("Import music", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var songList: some View {
        List {
            Section {
                ForEach(filteredSongs) { song in
                    SongRow(song: song) {
                        audioPlayer.play(song, from: filteredSongs)
                    }
                    .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteSongs)
            } header: {
                HStack {
                    Text(searchText.isEmpty ? "ALL SONGS" : "SEARCH RESULTS")
                    Spacer()
                    Text("\(filteredSongs.count) TRACKS")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption.weight(.semibold))
                .tracking(1)
            }
        }
        .listStyle(.plain)
        .overlay {
            if filteredSongs.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importMessage = error.localizedDescription

        case .success(let urls):
            guard !urls.isEmpty else { return }
            isImporting = true

            Task { @MainActor in
                var importedCount = 0
                var failures: [String] = []

                for sourceURL in urls {
                    var copiedURL: URL?

                    do {
                        let localURL = try MusicFileStore.importFile(from: sourceURL)
                        copiedURL = localURL
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
                        if let copiedURL {
                            try? FileManager.default.removeItem(at: copiedURL)
                        }
                        failures.append("\(sourceURL.lastPathComponent): \(error.localizedDescription)")
                    }
                }

                do {
                    try modelContext.save()
                } catch {
                    failures.append("Couldn't save the library: \(error.localizedDescription)")
                }

                isImporting = false

                if failures.isEmpty {
                    importMessage = "Added \(importedCount) song(s) to your library."
                } else {
                    importMessage = "Added \(importedCount) song(s).\n\n" + failures.joined(separator: "\n")
                }
            }
        }
    }

    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let song = filteredSongs[index]
            if audioPlayer.currentSong?.id == song.id {
                audioPlayer.stop()
            }
            let fileURL = MusicFileStore.musicDirectory.appendingPathComponent(song.fileName)
            try? FileManager.default.removeItem(at: fileURL)
            modelContext.delete(song)
        }
        try? modelContext.save()
    }
}
