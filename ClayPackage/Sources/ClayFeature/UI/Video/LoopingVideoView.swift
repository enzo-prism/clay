import SwiftUI
import AppKit
import AVFoundation

struct LoopingVideoView: NSViewRepresentable {
    let url: URL
    var isPlaying: Bool

    func makeNSView(context: Context) -> LoopingVideoNSView {
        let view = LoopingVideoNSView()
        view.configure(url: url, isPlaying: isPlaying)
        return view
    }

    func updateNSView(_ nsView: LoopingVideoNSView, context: Context) {
        nsView.configure(url: url, isPlaying: isPlaying)
    }

    static func dismantleNSView(_ nsView: LoopingVideoNSView, coordinator: ()) {
        nsView.teardown()
    }
}

final class LoopingVideoNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var currentURL: URL?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    func configure(url: URL, isPlaying: Bool) {
        if currentURL != url {
            currentURL = url
            configurePlayer(for: url)
        }

        player?.isMuted = true
        player?.volume = 0

        if isPlaying {
            player?.play()
        } else {
            player?.pause()
        }
    }

    func teardown() {
        player?.pause()
        playerLayer.player = nil
        looper = nil
        player = nil
        currentURL = nil
    }

    private func setup() {
        wantsLayer = true
        layer = CALayer()
        layer?.backgroundColor = NSColor.clear.cgColor

        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.clear.cgColor
        layer?.addSublayer(playerLayer)
    }

    private func configurePlayer(for url: URL) {
        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.actionAtItemEnd = .none
        player.isMuted = true
        player.volume = 0

        let looper = AVPlayerLooper(player: player, templateItem: item)

        self.player = player
        self.looper = looper
        playerLayer.player = player
    }
}

