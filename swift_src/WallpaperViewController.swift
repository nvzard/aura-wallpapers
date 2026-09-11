import Cocoa
import AVFoundation

/// View controller managing hardware-accelerated video playback and seamless looping
final class WallpaperViewController: NSViewController {
    let playerView = ClickThroughPlayerView()
    private(set) var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
    private var endObserver: NSObjectProtocol?
    private(set) var currentURL: URL?

    var isMuted: Bool = true {
        didSet { player?.isMuted = isMuted }
    }
    var volume: Float = 0.0 {
        didSet { player?.volume = volume }
    }

    override func loadView() {
        self.view = playerView
    }

    deinit {
        cleanupPlayer()
    }

    func cleanupPlayer() {
        if let obs = endObserver {
            NotificationCenter.default.removeObserver(obs)
            endObserver = nil
        }
        playerLooper?.disableLooping()
        playerLooper = nil
        if let p = player {
            p.pause()
            playerView.player = nil
            p.removeAllItems()
            player = nil
        }
    }

    func loadVideo(url: URL, for screen: NSScreen?) {
        cleanupPlayer()
        currentURL = url

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let queuePlayer = AVQueuePlayer(items: [item])
        queuePlayer.actionAtItemEnd = .none

        // Hardware-accelerated seamless looping
        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        // Safety fallback notification
        self.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak queuePlayer] _ in
            queuePlayer?.seek(to: .zero)
        }

        playerView.player = queuePlayer
        playerView.videoGravity = .resizeAspectFill
        queuePlayer.isMuted = isMuted
        queuePlayer.volume = volume
        queuePlayer.play()
        self.player = queuePlayer

        // Synchronize first frame to eliminate black flash on wake / boot
        if let screen = screen {
            syncFirstFrame(asset: asset, for: screen)
        }
    }

    func play() { player?.play() }
    func pause() { player?.pause() }
    var isPlaying: Bool { (player?.rate ?? 0.0) > 0.0 }

    private func syncFirstFrame(asset: AVAsset, for screen: NSScreen) {
        DispatchQueue.global(qos: .background).async {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(value: 1, timescale: 60)
            guard let imageRef = try? generator.copyCGImage(at: time, actualTime: nil) else { return }

            let rep = NSBitmapImageRep(cgImage: imageRef)
            guard let pngData = rep.representation(using: .png, properties: [:]) else { return }

            let cacheDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AuraWallpaper")
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            let fileURL = cacheDir.appendingPathComponent("preview_\(screen.hash).png")
            try? pngData.write(to: fileURL)

            DispatchQueue.main.async {
                try? NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: [:])
            }
        }
    }
}
