import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var audioPlayer: AudioPlayer
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]
    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var showingFolderPicker = false
    @State private var searchText = ""
    @State private var importMessage: String?
    @State private var isImporting = false

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return songs }
        return songs.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) || $0.album.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty { emptyLibrary } else { songList }
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("myuzick")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showingImporter = true } label: { Label("Choose music files", systemImage: "music.note") }
                        Button { showingFolderPicker = true } label: { Label("Import a folder", systemImage: "folder") }
                    } label: {
                        Image(systemName: "plus").font(.headline)
                    }
                    .disabled(isImporting)
                }
            }
            .searchable(text: $searchText, prompt: "Search your music")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environmentObject(audioPlayer)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.mp3], allowsMultipleSelection: true, onCompletion: handleImport)
            .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: handleFolderImport)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if audioPlayer.currentSong != nil {
                    MiniPlayer().padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4).background(.ultraThinMaterial)
                }
            }
            .alert("myuzick", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: { Text(importMessage ?? "") }
            .overlay {
                if isImporting { ProgressView("Importing music…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            }
        }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("Your music belongs here", systemImage: "music.note")
        } description: {
            Text("Import MP3 files or choose a folder in Files to add your music.")
        } actions: {
            Button { showingFolderPicker = true } label: { Label("Choose music folder", systemImage: "folder.badge.plus") }
                .buttonStyle(.borderedProminent)
        }
    }

    private var songList: some View {
        List {
            Section {
                ForEach(filteredSongs) { song in
                    SongRow(song: song) { audioPlayer.play(song, from: filteredSongs) }
                        .listRowBackground(Color.clear)
                }
                .onDelete(perform: deleteSongs)
            } header: {
                HStack {
                    Text(searchText.isEmpty ? "ALL SONGS" : "SEARCH RESULTS")
                    Spacer()
                    Text("\(filteredSongs.count) TRACKS").foregroundStyle(.tertiary)
                }
                .font(.caption.weight(.semibold)).tracking(1)
            }
        }
        .listStyle(.plain)
        .overlay { if filteredSongs.isEmpty { ContentUnavailableView.search(text: searchText) } }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): importMessage = error.localizedDescription
        case .success(let urls): importURLs(urls)
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): importMessage = error.localizedDescription
        case .success(let urls):
            guard let folder = urls.first else { return }
            isImporting = true
            Task { @MainActor in
                do {
                    let imported = try MusicFileStore.importFolder(from: folder)
                    await registerImportedFiles(imported)
                    importMessage = "Added \(imported.count) MP3 file(s) from that folder."
                } catch { importMessage = error.localizedDescription }
                isImporting = false
            }
        }
    }

    private func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        Task { @MainActor in
            var imported: [URL] = []
            for url in urls {
                do { imported.append(try MusicFileStore.importFile(from: url)) } catch { }
            }
            await registerImportedFiles(imported)
            isImporting = false
            importMessage = "Added \(imported.count) MP3 file(s)."
        }
    }

    private func registerImportedFiles(_ urls: [URL]) async {
        var count = 0
        for url in urls {
            do {
                let metadata = try await MetadataReader.read(from: url)
                modelContext.insert(Song(title: metadata.title, artist: metadata.artist, album: metadata.album, duration: metadata.duration, fileName: url.lastPathComponent, artworkData: metadata.artworkData))
                count += 1
            } catch { try? FileManager.default.removeItem(at: url) }
        }
        try? modelContext.save()
        if count == 0 && !urls.isEmpty { importMessage = "Couldn't read the selected audio files." }
    }

    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let song = filteredSongs[index]
            if audioPlayer.currentSong?.id == song.id { audioPlayer.stop() }
            try? FileManager.default.removeItem(at: MusicFileStore.musicDirectory.appendingPathComponent(song.fileName))
            modelContext.delete(song)
        }
        try? modelContext.save()
    }
}
