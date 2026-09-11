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

        let screens = NSScreen.screens
        let canReuse = !windows.isEmpty && windows.count == screens.count && windows.allSatisfy { w in
            guard let s = w.targetScreen else { return false }
            return screens.contains(s)
        }

        if canReuse {
            for window in windows {
                if let vc = window.contentViewController as? WallpaperViewController, let screen = window.targetScreen {
                    vc.loadVideo(url: url, for: screen)
                    if !isPlaying || isSleep {
                        vc.pause()
                    }
                    window.orderFront(nil)
                }
            }
        } else {
            rebuildWindows()
        }

        NotificationCenter.default.post(name: WallpaperManager.didChangeWallpaperNotification, object: self, userInfo: ["url": url])
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

    // MARK: - Wallpaper Library Helpers

    static let didChangeWallpaperNotification = Notification.Name("AuraWallpaperDidChangeNotification")

    static var userWallpapersDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("AuraWallpaper/Wallpapers", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func allAvailableWallpapers() -> [URL] {
        var results: [URL] = []
        var seenFileNames = Set<String>()
        let fm = FileManager.default
        let validExtensions = ["mp4", "mov", "m4v", "webm"]

        // 1. Bundled in Resources
        if let bundleResURL = Bundle.main.resourceURL,
           let contents = try? fm.contentsOfDirectory(at: bundleResURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                let name = fileURL.lastPathComponent.lowercased()
                if validExtensions.contains(ext) && !seenFileNames.contains(name) {
                    seenFileNames.insert(name)
                    results.append(fileURL)
                }
            }
        }

        // Fallback for CLI testing outside of bundle
        if results.isEmpty {
            let devAssetsPath = "assets"
            if fm.fileExists(atPath: devAssetsPath),
               let files = try? fm.contentsOfDirectory(atPath: devAssetsPath) {
                for file in files {
                    let ext = (file as NSString).pathExtension.lowercased()
                    let name = file.lowercased()
                    if validExtensions.contains(ext) && !seenFileNames.contains(name) {
                        let u = URL(fileURLWithPath: (devAssetsPath as NSString).appendingPathComponent(file)).standardized
                        seenFileNames.insert(name)
                        results.append(u)
                    }
                }
            }
        }

        // 2. User library wallpapers
        let userDir = userWallpapersDirectory
        if let userFiles = try? fm.contentsOfDirectory(at: userDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for fileURL in userFiles {
                let ext = fileURL.pathExtension.lowercased()
                let name = fileURL.lastPathComponent.lowercased()
                if validExtensions.contains(ext) && !seenFileNames.contains(name) {
                    seenFileNames.insert(name)
                    results.append(fileURL)
                }
            }
        }

        // 3. Current active wallpaper if not already present
        if let current = shared.currentVideoURL, fm.fileExists(atPath: current.path) {
            let name = current.lastPathComponent.lowercased()
            if !seenFileNames.contains(name) {
                seenFileNames.insert(name)
                results.append(current)
            }
        }

        return results.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    @discardableResult
    static func importWallpaper(at sourceURL: URL) throws -> URL {
        let fm = FileManager.default
        let targetDir = userWallpapersDirectory
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        var destURL = targetDir.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 1
        while fm.fileExists(atPath: destURL.path) {
            let newName = "\(baseName)_\(counter).\(ext)"
            destURL = targetDir.appendingPathComponent(newName)
            counter += 1
        }

        try fm.copyItem(at: sourceURL, to: destURL)
        return destURL
    }

    static func deleteUserWallpaper(at wallpaperURL: URL) throws {
        let userDir = userWallpapersDirectory
        guard wallpaperURL.path.hasPrefix(userDir.path) else {
            throw NSError(domain: "AuraWallpaper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot delete bundled wallpaper."])
        }
        try FileManager.default.removeItem(at: wallpaperURL)
    }
}
