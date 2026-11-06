import Foundation
import TagLibSwift

enum MetadataWriter {
    static func update(
        fileURL: URL,
        title: String,
        artist: String,
        album: String
    ) throws {
        guard let file = AudioFile(path: fileURL.path), file.isValid else {
            throw MetadataError.unreadableFile
        }
        file.tag.title = title
        file.tag.artist = artist
        file.tag.album = album
        try file.save()
    }

    enum MetadataError: LocalizedError {
        case unreadableFile
        var errorDescription: String? {
            "This audio file could not be opened for metadata editing."
        }
    }
}
