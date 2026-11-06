import Foundation
import SwiftData

@Model
final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    var album: String
    var duration: Double
    var fileName: String
    var artworkData: Data?\n    var animatedCoverFileName: String?
    var dateAdded: Date

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        duration: Double = 0,
        fileName: String,
        artworkData: Data? = nil,
        dateAdded: Date = .now
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.fileName = fileName
        self.artworkData = artworkData
        self.dateAdded = dateAdded
    }

    var displayTitle: String {
        title.isEmpty ? URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent : title
    }
}
