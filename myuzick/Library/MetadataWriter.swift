import Foundation
import TagLibSwift

enum MetadataWriter {
    static func update(
        fileURL: URL,
        title: String,
        artist: String,
        album: String,
        artworkData: Data? = nil
    ) throws {
        guard let file = AudioFile(path: fileURL.path), file.isValid else {
            throw MetadataError.unreadableFile
        }
        file.tag.title = title
        file.tag.artist = artist
        file.tag.album = album
        if let artworkData {
            let mimeType = artworkData.starts(with: [0x89, 0x50, 0x4E, 0x47]) ? "image/png" : "image/jpeg"
            file.setPictures([
                Picture(data: artworkData, mimeType: mimeType, description: "cover", pictureType: .frontCover)
            ])
        }
        try file.save()
    }

    enum MetadataError: LocalizedError {
        case unreadableFile
        var errorDescription: String? {
            "This audio file could not be opened for metadata editing."
        }
    }
}
