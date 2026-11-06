import Foundation

enum MusicFileStore {
    static let musicDirectory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    private static let bookmarkKey = "myuzick.originalMusicFolderBookmark"
    static let linkedPrefix = "linked://"

    static func importFile(from sourceURL: URL) throws -> URL {
        let access = sourceURL.startAccessingSecurityScopedResource()
        defer { if access { sourceURL.stopAccessingSecurityScopedResource() } }
        guard sourceURL.pathExtension.lowercased() == "mp3" else { throw ImportError.unsupportedFormat }
        let destination = uniqueDestination(for: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func importFolder(from folderURL: URL) throws -> [URL] {
        let bookmark = try folderURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        return try scanOriginalFolder(at: folderURL)
    }

    static func startOriginalFolderAccess() -> (url: URL, accessed: Bool)? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale, let updated = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(updated, forKey: bookmarkKey)
        }
        return (url, url.startAccessingSecurityScopedResource())
    }

    static func scanOriginalFolder(at folder: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            throw ImportError.unreadableFolder
        }
        var result: [URL] = []
        for case let url as URL in enumerator where url.pathExtension.lowercased() == "mp3" {
            if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { result.append(url) }
        }
        return result
    }

    static func storedPath(for file: URL, in folder: URL) -> String {
        linkedPrefix + String(file.standardizedFileURL.path.dropFirst(folder.standardizedFileURL.path.count + 1))
    }

    static func isLinked(_ path: String) -> Bool { path.hasPrefix(linkedPrefix) }

    static func resolve(_ path: String, in folder: URL? = nil) -> URL {
        if isLinked(path) {
            let root = folder ?? originalFolderURL()
            let relative = String(path.dropFirst(linkedPrefix.count))
            if let root { return root.appendingPathComponent(relative) }
        }
        return musicDirectory.appendingPathComponent(path)
    }

    static func originalFolderURL() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    static func sidecarURL(for path: String) -> URL {
        resolve(path).deletingPathExtension().appendingPathExtension("lrc")
    }

    static func clearFolderBookmark() { UserDefaults.standard.removeObject(forKey: bookmarkKey) }

    private static func uniqueDestination(for name: String) -> URL {
        let base = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: name).pathExtension
        var candidate = musicDirectory.appendingPathComponent(name)
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = musicDirectory.appendingPathComponent("\(base)-\(suffix).\(ext)")
            suffix += 1
        }
        return candidate
    }

    enum ImportError: LocalizedError {
        case unsupportedFormat, unreadableFolder
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "This version supports MP3 files only."
            case .unreadableFolder: return "Couldn't read that folder."
            }
        }
    }
}
