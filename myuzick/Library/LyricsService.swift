import Foundation

struct LyricToken: Identifiable {
    let id = UUID()
    let text: String
    let time: TimeInterval
}

struct LyricLine: Identifiable {
    let id = UUID()
    let time: TimeInterval
    let text: String
    let words: [LyricToken]
}

enum LyricsService {
    static func fetch(for song: Song) async throws -> [LyricLine] {
        let access = MusicFileStore.isLinked(song.fileName) ? MusicFileStore.startOriginalFolderAccess() : nil
        defer { if let access, access.accessed { access.url.stopAccessingSecurityScopedResource() } }
        let sidecar = MusicFileStore.sidecarURL(for: song.fileName)
        if let data = try? Data(contentsOf: sidecar), let text = String(data: data, encoding: .utf8) {
            let parsed = parse(text)
            if !parsed.isEmpty { return parsed }
        }
        var components = URLComponents(string: "https://lrclib.net/api/get")!
        components.queryItems = [
            URLQueryItem(name: "track_name", value: song.displayTitle),
            URLQueryItem(name: "artist_name", value: song.artist),
            URLQueryItem(name: "album_name", value: song.album),
            URLQueryItem(name: "duration", value: String(Int(song.duration)))
        ]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(LRCLibResponse.self, from: data)
        guard let lyrics = response.syncedLyrics ?? response.plainLyrics else { throw LyricsError.notFound }
        let parsed = parse(lyrics)
        guard !parsed.isEmpty else { throw LyricsError.notFound }
        return parsed
    }

    static func parse(_ text: String) -> [LyricLine] {
        let wordRegex = try? NSRegularExpression(pattern: #"<(\d{2}):(\d{2})\.(\d{2,3})>([^<]+)"#)
        let lineRegex = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"#)
        return text.components(separatedBy: .newlines).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { return nil }
            let range = NSRange(line.startIndex..., in: line)
            let matches = wordRegex?.matches(in: line, range: range) ?? []
            if !matches.isEmpty {
                let tokens: [LyricToken] = matches.compactMap { match in
                    guard let minR = Range(match.range(at: 1), in: line),
                          let secR = Range(match.range(at: 2), in: line),
                          let fracR = Range(match.range(at: 3), in: line),
                          let textR = Range(match.range(at: 4), in: line),
                          let min = Double(line[minR]), let sec = Double(line[secR]),
                          let frac = Double("0." + line[fracR]) else { return nil }
                    return LyricToken(text: String(line[textR]), time: min * 60 + sec + frac)
                }
                if let first = tokens.first { return LyricLine(time: first.time, text: tokens.map(\.text).joined(), words: tokens) }
            }
            guard let match = lineRegex?.firstMatch(in: line, range: range),
                  let minR = Range(match.range(at: 1), in: line),
                  let secR = Range(match.range(at: 2), in: line),
                  let fracR = Range(match.range(at: 3), in: line),
                  let textR = Range(match.range(at: 4), in: line),
                  let min = Double(line[minR]), let sec = Double(line[secR]),
                  let frac = Double("0." + line[fracR]) else { return nil }
            return LyricLine(time: min * 60 + sec + frac, text: String(line[textR]), words: [])
        }.sorted { $0.time < $1.time }
    }

    private struct LRCLibResponse: Decodable {
        let syncedLyrics: String?
        let plainLyrics: String?
    }
    enum LyricsError: LocalizedError {
        case notFound
        var errorDescription: String? { "No synced lyrics were found for this track." }
    }
}
