import Cocoa

/// Orchestrator for all monitors, power/sleep states, and wallpaper playback
final class WallpaperManager {
    static let shared = WallpaperManager()

    private var windows: [WallpaperWindow] = []
    private var isSleep: Bool = false
    private(set) var currentVideoURL: URL?
    private(set) var isPlaying: Bool = true
    private(set) var isMuted: Bool = true
    private(set) var hidesDesktopIcons: Bool = false

    private let kSavedPath = "AuraWallpaperSavedPath"
    private let kSavedMuted = "AuraWallpaperMuted"
    private let kSavedHideIcons = "AuraWallpaperHideIcons"

    init() {
        let defs = UserDefaults.standard
        self.isMuted = defs.object(forKey: kSavedMuted) != nil ? defs.bool(forKey: kSavedMuted) : true
        self.hidesDesktopIcons = defs.bool(forKey: kSavedHideIcons)

        setupNotifications()
    }

    private func setupNotifications() {
        let ws = NSWorkspace.shared.notificationCenter

        // Multi-monitor connect/disconnect/resolution changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuildWindows()
        }

        // Display sleep & wake power management
        ws.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isSleep = true
            self?.pauseAll()
        }
        ws.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.isSleep = false
            if self?.isPlaying == true {
                self?.playAll()
            }
        }
        ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.windows.forEach { $0.updateFrameForScreen() }
        }
    }

    func startWithDefaultOrSavedWallpaper() {
        if let saved = UserDefaults.standard.string(forKey: kSavedPath),
           FileManager.default.fileExists(atPath: saved) {
            setWallpaper(url: URL(fileURLWithPath: saved))
            return
        }

        if let bundled = Bundle.main.url(forResource: "default_wallpaper", withExtension: "mp4") {
            setWallpaper(url: bundled)
        }
    }

    func setWallpaper(url: URL) {
        self.currentVideoURL = url
        self.isPlaying = true
        UserDefaults.standard.set(url.path, forKey: kSavedPath)
        rebuildWindows()
    }

    func rebuildWindows() {
        windows.forEach { $0.close() }
        windows.removeAll()

        guard let videoURL = currentVideoURL else { return }

        for screen in NSScreen.screens {
            let window = WallpaperWindow(screen: screen)
            let vc = WallpaperViewController()
            vc.isMuted = isMuted

            window.contentViewController = vc
            window.setHidesDesktopIcons(hidesDesktopIcons)
            window.setFrame(screen.frame, display: true)
            window.orderFront(nil)

            vc.loadVideo(url: videoURL, for: screen)
            if !isPlaying || isSleep {
                vc.pause()
            }
            windows.append(window)
        }
    }

    func playAll() {
        isPlaying = true
        windows.compactMap { $0.contentViewController as? WallpaperViewController }.forEach { $0.play() }
    }

    func pauseAll() {
        isPlaying = false
        windows.compactMap { $0.contentViewController as? WallpaperViewController }.forEach { $0.pause() }
    }

    func togglePlayPause() {
        if isPlaying { pauseAll() } else { playAll() }
    }

    func setMuted(_ muted: Bool) {
        self.isMuted = muted
        UserDefaults.standard.set(muted, forKey: kSavedMuted)
        windows.compactMap { $0.contentViewController as? WallpaperViewController }.forEach { $0.isMuted = muted }
    }

    func setHidesDesktopIcons(_ hide: Bool) {
        self.hidesDesktopIcons = hide
        UserDefaults.standard.set(hide, forKey: kSavedHideIcons)
        windows.forEach { $0.setHidesDesktopIcons(hide) }
    }
}
