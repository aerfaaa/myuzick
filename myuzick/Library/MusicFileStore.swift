import Foundation

enum MusicFileStore {
    static let musicDirectory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("Music", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()

    static func importFile(from sourceURL: URL) throws -> URL {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }
        guard sourceURL.pathExtension.lowercased() == "mp3" else { throw ImportError.unsupportedFormat }
        let destination = uniqueDestination(for: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
    }

    static func importFolder(from folderURL: URL) throws -> [URL] {
        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if didAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { throw ImportError.unreadableFolder }

        var imported: [URL] = []
        for case let sourceURL as URL in enumerator where sourceURL.pathExtension.lowercased() == "mp3" {
            do {
                let destination = uniqueDestination(for: sourceURL.lastPathComponent)
                try FileManager.default.copyItem(at: sourceURL, to: destination)
                imported.append(destination)
            } catch {
                continue
            }
        }
        return imported
    }

    private static func uniqueDestination(for fileName: String) -> URL {
        let base = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let ext = URL(fileURLWithPath: fileName).pathExtension
        var candidate = musicDirectory.appendingPathComponent(fileName)
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = musicDirectory.appendingPathComponent("\(base)-\(suffix).\(ext)")
            suffix += 1
        }
        return candidate
    }

    enum ImportError: LocalizedError {
        case unsupportedFormat
        case unreadableFolder
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "This version supports MP3 files only."
            case .unreadableFolder: return "Couldn't read that folder."
            }
        }
    }
}
