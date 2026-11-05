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
        defer {
            if didAccess { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == "mp3" else {
            throw ImportError.unsupportedFormat
        }

        let destination = uniqueDestination(for: sourceURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return destination
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

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "This first version supports MP3 files only."
            }
        }
    }
}
