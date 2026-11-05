import AVFoundation
import Foundation

struct AudioMetadata {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let artworkData: Data?
}

enum MetadataReader {
    static func read(from url: URL) async throws -> AudioMetadata {
        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)
        let duration = durationTime.seconds.isFinite ? durationTime.seconds : 0
        let metadata = try await asset.load(.commonMetadata)

        func stringValue(for identifier: AVMetadataIdentifier) async -> String? {
            guard let item = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: identifier
            ).first else {
                return nil
            }
            return try? await item.load(.stringValue)
        }

        let title = await stringValue(for: .commonIdentifierTitle)
        let artist = await stringValue(for: .commonIdentifierArtist)
        let album = await stringValue(for: .commonIdentifierAlbumName)

        let artworkItem = AVMetadataItem.metadataItems(
            from: metadata,
            filteredByIdentifier: .commonIdentifierArtwork
        ).first
        let artwork = try? await artworkItem?.load(.dataValue)

        return AudioMetadata(
            title: title?.nilIfEmpty ?? url.deletingPathExtension().lastPathComponent,
            artist: artist?.nilIfEmpty ?? "Unknown Artist",
            album: album?.nilIfEmpty ?? "Unknown Album",
            duration: duration,
            artworkData: artwork ?? nil
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
