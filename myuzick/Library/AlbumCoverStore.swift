import Foundation

enum AlbumCoverStore {
    private static let storageKey = "myuzick.animatedAlbumCovers"

    static func filename(for song: Song) -> String? {
        dictionary[key(for: song)]
    }

    static func set(_ filename: String, for song: Song) {
        var values = dictionary
        values[key(for: song)] = filename
        UserDefaults.standard.set(values, forKey: storageKey)
    }

    @discardableResult
    static func remove(for song: Song) -> String? {
        var values = dictionary
        let old = values.removeValue(forKey: key(for: song))
        UserDefaults.standard.set(values, forKey: storageKey)
        return old
    }

    private static var dictionary: [String: String] {
        UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    private static func key(for song: Song) -> String {
        "\(song.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())|\(song.album.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }
}
