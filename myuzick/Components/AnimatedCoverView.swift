import AVFoundation
import SwiftUI
import UIKit

struct AnimatedCoverView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        context.coordinator.configure(url: url, in: view)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {
        context.coordinator.configure(url: url, in: uiView)
    }

    static func dismantleUIView(_ uiView: PlayerLayerView, coordinator: Coordinator) {
        coordinator.stop()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?
        private var currentURL: URL?

        func configure(url: URL, in view: PlayerLayerView) {
            guard currentURL != url else { return }
            stop()
            currentURL = url
            let queue = AVQueuePlayer()
            queue.isMuted = true
            let item = AVPlayerItem(url: url)
            looper = AVPlayerLooper(player: queue, templateItem: item)
            player = queue
            view.playerLayer.player = queue
            queue.play()
        }

        func stop() {
            player?.pause()
            player?.removeAllItems()
            looper = nil
            player = nil
            currentURL = nil
        }
    }
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
