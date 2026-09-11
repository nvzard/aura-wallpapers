import Cocoa
import UniformTypeIdentifiers
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var playPauseItem: NSMenuItem!
    private var muteItem: NSMenuItem!
    private var hideIconsItem: NSMenuItem!
    private var openAtLoginItem: NSMenuItem!
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

        let libraryItem = NSMenuItem(title: "Open Wallpaper Library...", action: #selector(openWallpaperLibraryAction), keyEquivalent: "l")
        libraryItem.target = self
        menu.addItem(libraryItem)

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

        openAtLoginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleOpenAtLoginAction), keyEquivalent: "")
        openAtLoginItem.target = self
        menu.addItem(openAtLoginItem)

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
        openAtLoginItem.state = isOpenAtLoginEnabled ? .on : .off
    }

    private var isOpenAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return UserDefaults.standard.bool(forKey: "OpenAtLogin")
        }
    }

    @objc private func toggleOpenAtLoginAction() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled {
                    try service.unregister()
                } else {
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    } else {
                        try service.register()
                    }
                }
            } catch {
                NSLog("[AuraWallpaper] Error toggling Open at Login: \(error)")
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } else {
            let current = UserDefaults.standard.bool(forKey: "OpenAtLogin")
            UserDefaults.standard.set(!current, forKey: "OpenAtLogin")
        }
        openAtLoginItem.state = isOpenAtLoginEnabled ? .on : .off
    }

    @objc private func openWallpaperLibraryAction() {
        WallpaperLibraryWindowController.shared.showLibrary()
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
