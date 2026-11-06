import CryptoKit
import Foundation

enum LastFMScrobbler {
    static func requestAuthorization(apiKey: String, sharedSecret: String) async throws -> URL {
        let token = try await signedRequest(
            parameters: ["api_key": apiKey, "method": "auth.getToken"],
            sharedSecret: sharedSecret
        )["token"] as? String
        guard let token else { throw AuthenticationError.invalidResponse }
        var components = URLComponents(string: "https://www.last.fm/api/auth/")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "token", value: token)
        ]
        guard let url = components.url else { throw AuthenticationError.invalidResponse }
        UserDefaults.standard.set(token, forKey: "lastfmPendingAuthToken")
        return url
    }

    static func finishAuthorization(apiKey: String, sharedSecret: String) async throws -> (username: String, sessionKey: String) {
        guard let token = UserDefaults.standard.string(forKey: "lastfmPendingAuthToken") else {
            throw AuthenticationError.missingToken
        }
        let response = try await signedRequest(
            parameters: ["api_key": apiKey, "method": "auth.getSession", "token": token],
            sharedSecret: sharedSecret
        )
        guard let session = response["session"] as? [String: Any],
              let key = session["key"] as? String,
              let username = session["name"] as? String else {
            throw AuthenticationError.invalidResponse
        }
        UserDefaults.standard.removeObject(forKey: "lastfmPendingAuthToken")
        return (username, key)
    }

    private static func signedRequest(parameters: [String: String], sharedSecret: String) async throws -> [String: Any] {
        let source = parameters.keys.sorted().map { "\($0)\(parameters[$0] ?? "")" }.joined() + sharedSecret
        let digest = Insecure.MD5.hash(data: Data(source.utf8))
        var signed = parameters
        signed["api_sig"] = digest.map { String(format: "%02x", $0) }.joined()
        signed["format"] = "json"
        var request = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = signed.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthenticationError.server
        }
        if let error = object["error"] {
            throw AuthenticationError.rejected(object["message"] as? String ?? String(describing: error))
        }
        return object
    }

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

    enum AuthenticationError: LocalizedError {
        case server, invalidResponse, missingToken, rejected(String)
        var errorDescription: String? {
            switch self {
            case .server: return "Last.fm authentication server could not be reached."
            case .invalidResponse: return "Last.fm returned an unexpected authentication response."
            case .missingToken: return "Start the Last.fm connection process again."
            case .rejected(let message): return message
            }
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
