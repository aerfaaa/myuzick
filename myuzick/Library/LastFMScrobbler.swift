import CryptoKit
import Foundation

enum LastFMScrobbler {
    static func scrobble(song: Song, timestamp: Int, apiKey: String, sharedSecret: String, sessionKey: String) async throws {
        var parameters: [String: String] = [
            "api_key": apiKey,
            "artist": song.artist,
            "album": song.album,
            "duration": String(Int(song.duration)),
            "method": "track.scrobble",
            "sk": sessionKey,
            "timestamp": String(timestamp),
            "track": song.displayTitle
        ]
        let signatureSource = parameters.keys.sorted().map { "\($0)\(parameters[$0] ?? "")" }.joined() + sharedSecret
        let digest = Insecure.MD5.hash(data: Data(signatureSource.utf8))
        parameters["api_sig"] = digest.map { String(format: "%02x", $0) }.joined()
        parameters["format"] = "json"

        var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ScrobbleError.server
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object["error"] != nil {
            throw ScrobbleError.rejected(object["message"] as? String ?? "Last.fm rejected the scrobble.")
        }
    }

    enum ScrobbleError: LocalizedError {
        case server
        case rejected(String)
        var errorDescription: String? {
            switch self {
            case .server: return "Last.fm couldn't be reached."
            case .rejected(let message): return message
            }
        }
    }
}
