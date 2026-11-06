import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.audioPlayerReference) private var audioPlayerReference
    private var audioPlayer: AudioPlayer { audioPlayerReference! }
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]
    @State private var showingImporter = false
    @State private var showingSettings = false
    @State private var showingFolderPicker = false
    @State private var searchText = ""
    @State private var importMessage: String?
    @State private var isImporting = false
    @State private var editingSong: Song?

    private var filteredSongs: [Song] {
        guard !searchText.isEmpty else { return songs }
        return songs.filter { $0.displayTitle.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) || $0.album.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group { if songs.isEmpty { emptyLibrary } else { songList } }
                .background(Color(uiColor: .systemBackground))
                .navigationTitle("myuzick")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { showingImporter = true } label: { Label("Import files (copy)", systemImage: "music.note") }
                            Button { showingFolderPicker = true } label: { Label("Link original folder", systemImage: "folder") }
                            if songs.contains(where: { MusicFileStore.isLinked($0.fileName) }) {
                                Button { refreshLinkedFolder() } label: { Label("Refresh linked folder", systemImage: "arrow.clockwise") }
                                Button(role: .destructive) { unlinkFolder() } label: { Label("Unlink folder", systemImage: "folder.badge.minus") }
                            }
                        } label: { Image(systemName: "plus").font(.headline) }
                        .disabled(isImporting)
                    }
                }
                .searchable(text: $searchText, prompt: "Search your music")
                .sheet(item: $editingSong) { song in
                    MetadataEditorView(song: song)
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView().environmentObject(audioPlayer).presentationDetents([.large]).presentationDragIndicator(.visible)
                }
                .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true, onCompletion: handleImport)
                .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: handleFolderImport)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if audioPlayer.currentSong != nil {
                        MiniPlayer().padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 4).background(.ultraThinMaterial)
                    }
                }
                .alert("myuzick", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
                    Button("OK", role: .cancel) { importMessage = nil }
                } message: { Text(importMessage ?? "") }
                .overlay { if isImporting { ProgressView("Scanning music…").padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
                .task { refreshLinkedFolder(silent: true) }
        }
    }

    private var emptyLibrary: some View {
        ContentUnavailableView {
            Label("Your music belongs here", systemImage: "music.note")
        } description: {
            Text("Link a folder in Files to play supported audio files without copying them into myuzick.")
        } actions: {
            Button { showingFolderPicker = true } label: { Label("Link music folder", systemImage: "folder.badge.plus") }.buttonStyle(.borderedProminent)
        }
    }

    private var songList: some View {
        List {
            Section {
                ForEach(filteredSongs) { song in
                    SongRow(song: song) { audioPlayer.play(song, from: filteredSongs) }
                        .contextMenu {
                            Button { editingSong = song } label: { Label("Edit Metadata", systemImage: "pencil") }
                            Button { audioPlayer.addToQueue(song) } label: { Label("Add to Queue", systemImage: "text.badge.plus") }
                            Button { audioPlayer.playNext(song) } label: { Label("Play Next", systemImage: "text.insert") }
                        }
                        .listRowBackground(Color.clear)
                }.onDelete(perform: deleteSongs)
            } header: {
                HStack {
                    Text(searchText.isEmpty ? "ALL SONGS" : "SEARCH RESULTS")
                    Spacer()
                    Text("\(filteredSongs.count) TRACKS").foregroundStyle(.tertiary)
                }.font(.caption.weight(.semibold)).tracking(1)
            }
        }.listStyle(.plain).overlay { if filteredSongs.isEmpty { ContentUnavailableView.search(text: searchText) } }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): importMessage = error.localizedDescription
        case .success(let urls): importCopiedURLs(urls)
        }
    }

    private func handleFolderImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): importMessage = error.localizedDescription
        case .success(let urls):
            guard let folder = urls.first else { return }
            isImporting = true
            Task { @MainActor in
                let didAccess = folder.startAccessingSecurityScopedResource()
                defer { if didAccess { folder.stopAccessingSecurityScopedResource() }; isImporting = false }
                do {
                    let files = try MusicFileStore.importFolder(from: folder)
                    let count = await registerLinkedFiles(files, in: folder)
                    importMessage = "Linked \(count) original audio file(s). No audio files were copied."
                } catch { importMessage = error.localizedDescription }
            }
        }
    }

    private func importCopiedURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        Task { @MainActor in
            var copies: [URL] = []
            for url in urls { if let copy = try? MusicFileStore.importFile(from: url) { copies.append(copy) } }
            for url in copies {
                guard let metadata = try? await MetadataReader.read(from: url) else { continue }
                modelContext.insert(Song(title: metadata.title, artist: metadata.artist, album: metadata.album, duration: metadata.duration, fileName: url.lastPathComponent, artworkData: metadata.artworkData))
            }
            try? modelContext.save()
            isImporting = false
            importMessage = "Imported \(copies.count) copied audio file(s)."
        }
    }

    private func registerLinkedFiles(_ files: [URL], in folder: URL) async -> Int {
        let existing = Set(songs.filter { MusicFileStore.isLinked($0.fileName) }.map(\.fileName))
        var added = 0
        for file in files {
            let storedPath = MusicFileStore.storedPath(for: file, in: folder)
            guard !existing.contains(storedPath), let metadata = try? await MetadataReader.read(from: file) else { continue }
            modelContext.insert(Song(title: metadata.title, artist: metadata.artist, album: metadata.album, duration: metadata.duration, fileName: storedPath, artworkData: metadata.artworkData))
            added += 1
        }
        try? modelContext.save()
        return added
    }

    private func refreshLinkedFolder(silent: Bool = false) {
        guard let access = MusicFileStore.startOriginalFolderAccess() else { return }
        Task { @MainActor in
            defer { if access.accessed { access.url.stopAccessingSecurityScopedResource() } }
            do {
                let files = try MusicFileStore.scanOriginalFolder(at: access.url)
                let available = Set(files.map { MusicFileStore.storedPath(for: $0, in: access.url) })
                for song in songs where MusicFileStore.isLinked(song.fileName) && !available.contains(song.fileName) {
                    if audioPlayer.currentSong?.id == song.id { audioPlayer.stop() }
                    modelContext.delete(song)
                }
                _ = await registerLinkedFiles(files, in: access.url)
                try? modelContext.save()
                if !silent { importMessage = "Folder refreshed. The library now matches supported audio files in the original folder." }
            } catch { if !silent { importMessage = error.localizedDescription } }
        }
    }

    private func unlinkFolder() {
        MusicFileStore.clearFolderBookmark()
        for song in songs where MusicFileStore.isLinked(song.fileName) {
            if audioPlayer.currentSong?.id == song.id { audioPlayer.stop() }
            modelContext.delete(song)
        }
        try? modelContext.save()
        importMessage = "Folder unlinked. Original files were left untouched."
    }

    private func deleteSongs(at offsets: IndexSet) {
        for index in offsets {
            let song = filteredSongs[index]
            if audioPlayer.currentSong?.id == song.id { audioPlayer.stop() }
            if !MusicFileStore.isLinked(song.fileName) {
                try? FileManager.default.removeItem(at: MusicFileStore.musicDirectory.appendingPathComponent(song.fileName))
            }
            modelContext.delete(song)
        }
        try? modelContext.save()
    }
}
