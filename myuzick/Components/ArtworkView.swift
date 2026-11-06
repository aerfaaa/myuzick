import SwiftUI

struct ArtworkView: View {
    private static let cache = NSCache<NSString, UIImage>()
    private var decodedImage: UIImage? {
        guard let data else { return nil }
        let key = NSString(string: String(data.hashValue))
        if let image = Self.cache.object(forKey: key) { return image }
        guard let image = UIImage(data: data) else { return nil }
        Self.cache.setObject(image, forKey: key)
        return image
    }
    let data: Data?

    var body: some View {
        Group {
            if let image = decodedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color(white: 0.22), Color(white: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .clipped()
    }
}
