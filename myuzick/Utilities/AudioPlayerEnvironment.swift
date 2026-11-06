import SwiftUI

private struct AudioPlayerReferenceKey: EnvironmentKey {
    static let defaultValue: AudioPlayer? = nil
}

extension EnvironmentValues {
    var audioPlayerReference: AudioPlayer? {
        get { self[AudioPlayerReferenceKey.self] }
        set { self[AudioPlayerReferenceKey.self] = newValue }
    }
}
