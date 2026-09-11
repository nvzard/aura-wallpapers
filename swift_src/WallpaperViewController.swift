import Cocoa
import AVFoundation

/// View controller managing hardware-accelerated video playback and seamless looping
final class WallpaperViewController: NSViewController {
    static var desktopSyncEnabled: Bool = true
    static var isDesktopSyncEnabled: Bool {
        if ProcessInfo.processInfo.environment["AURA_TEST_MODE"] != nil {
            return false
        }
        return desktopSyncEnabled
    }

    static var previewsDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let dir = appSupport?.appendingPathComponent("AuraWallpaper/Previews", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AuraWallpaper/Previews", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static let syncQueue = DispatchQueue(label: "com.nitanshu.aurawallpaper.desktopsync")
    private var syncGeneration: UInt64 = 0

    let playerView = ClickThroughPlayerView()
    private(set) var player: AVQueuePlayer?
    private var playerLooper: AVPlayerLooper?
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
        syncGeneration &+= 1
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
        currentURL = url
        syncGeneration &+= 1
        let currentGen = syncGeneration

        let oldPlayer = player
        let oldLooper = playerLooper

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        let queuePlayer = AVQueuePlayer()
        queuePlayer.actionAtItemEnd = .none

        // Hardware-accelerated seamless looping
        self.playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)

        self.player = queuePlayer
        playerView.player = queuePlayer
        playerView.videoGravity = .resizeAspectFill
        queuePlayer.isMuted = isMuted
        queuePlayer.volume = volume
        queuePlayer.play()

        // Clean up old playback after handing off to prevent black flash
        oldLooper?.disableLooping()
        oldPlayer?.pause()
        oldPlayer?.removeAllItems()

        // Synchronize first frame to eliminate black flash on wake / boot
        if let screen = screen {
            syncFirstFrame(asset: asset, for: screen, generation: currentGen)
        }
    }

    func play() { player?.play() }
    func pause() { player?.pause() }
    var isPlaying: Bool { (player?.rate ?? 0.0) > 0.0 }

    private func syncFirstFrame(asset: AVAsset, for screen: NSScreen, generation: UInt64) {
        guard Self.isDesktopSyncEnabled else { return }
        Self.syncQueue.async { [weak self] in
            guard let self = self, self.syncGeneration == generation else { return }

            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .positiveInfinity
            generator.requestedTimeToleranceAfter = .positiveInfinity
            let time = CMTime(value: 1, timescale: 60)

            var imageRef: CGImage? = try? generator.copyCGImage(at: time, actualTime: nil)
            if imageRef == nil {
                imageRef = try? generator.copyCGImage(at: .zero, actualTime: nil)
            }
            guard let img = imageRef else { return }

            let rep = NSBitmapImageRep(cgImage: img)
            let props: [NSBitmapImageRep.PropertyKey: Any] = [.compressionFactor: 0.85]
            guard let jpegData = rep.representation(using: .jpeg, properties: props), !jpegData.isEmpty else { return }

            let screenID: UInt
            if let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                screenID = num.uintValue
            } else {
                screenID = UInt(bitPattern: screen.hash)
            }

            let previewsDir = Self.previewsDirectory
            let fileName = String(format: "preview_%lx_%lx.jpg", UInt(bitPattern: (self.currentURL?.path ?? "").hashValue), screenID)
            let fileURL = previewsDir.appendingPathComponent(fileName)

            guard (try? jpegData.write(to: fileURL, options: .atomic)) != nil else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.syncGeneration == generation else { return }
                let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
                    .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                    .allowClipping: true
                ]
                try? NSWorkspace.shared.setDesktopImageURL(fileURL, for: screen, options: options)
            }
        }
    }
}
