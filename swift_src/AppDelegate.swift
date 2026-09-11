import Cocoa
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var playPauseItem: NSMenuItem!
    private var muteItem: NSMenuItem!
    private var hideIconsItem: NSMenuItem!
    private var currentFileItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
            button.image = NSImage(systemSymbolName: "sparkles.tv", accessibilityDescription: "Aura Live Wallpaper")?
                .withSymbolConfiguration(config)
        }

        setupMenu()
        WallpaperManager.shared.startWithDefaultOrSavedWallpaper()
    }

    private func setupMenu() {
        let menu = NSMenu(title: "Aura Wallpaper")
        menu.delegate = self

        currentFileItem = NSMenuItem(title: "Aura Live Wallpaper", action: nil, keyEquivalent: "")
        currentFileItem.isEnabled = false
        menu.addItem(currentFileItem)
        menu.addItem(NSMenuItem.separator())

        let chooseItem = NSMenuItem(title: "Choose Video Wallpaper...", action: #selector(chooseVideoAction), keyEquivalent: "o")
        chooseItem.target = self
        menu.addItem(chooseItem)

        playPauseItem = NSMenuItem(title: "Pause Wallpaper", action: #selector(togglePlayPauseAction), keyEquivalent: "p")
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        muteItem = NSMenuItem(title: "Unmute Audio", action: #selector(toggleMuteAction), keyEquivalent: "m")
        muteItem.target = self
        menu.addItem(muteItem)

        menu.addItem(NSMenuItem.separator())

        hideIconsItem = NSMenuItem(title: "Hide Desktop Icons", action: #selector(toggleHideIconsAction), keyEquivalent: "h")
        hideIconsItem.target = self
        menu.addItem(hideIconsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Aura Wallpaper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let mgr = WallpaperManager.shared
        if let url = mgr.currentVideoURL {
            currentFileItem.title = "Playing: \(url.lastPathComponent)"
        } else {
            currentFileItem.title = "No Wallpaper Active"
        }

        playPauseItem.title = mgr.isPlaying ? "Pause Wallpaper" : "Resume Wallpaper"
        muteItem.title = mgr.isMuted ? "Unmute Audio" : "Mute Audio"
        hideIconsItem.state = mgr.hidesDesktopIcons ? .on : .off
    }

    @objc private func chooseVideoAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.message = "Select a high-definition video wallpaper:"

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            if response == .OK, let url = panel.url {
                WallpaperManager.shared.setWallpaper(url: url)
            }
        }
    }

    @objc private func togglePlayPauseAction() {
        WallpaperManager.shared.togglePlayPause()
    }

    @objc private func toggleMuteAction() {
        WallpaperManager.shared.setMuted(!WallpaperManager.shared.isMuted)
    }

    @objc private func toggleHideIconsAction() {
        WallpaperManager.shared.setHidesDesktopIcons(!WallpaperManager.shared.hidesDesktopIcons)
    }
}
