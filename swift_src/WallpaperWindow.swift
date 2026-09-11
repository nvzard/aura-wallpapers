import Cocoa

/// Custom borderless window positioned at the desktop window level behind Finder icons
final class WallpaperWindow: NSWindow {
    weak var targetScreen: NSScreen?
    private(set) var hidesDesktopIcons: Bool = false

    init(screen: NSScreen) {
        self.targetScreen = screen
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        self.isReleasedWhenClosed = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.animationBehavior = .none

        // Position behind desktop icons: -2147483623
        self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))

        // Keep visible on all virtual spaces & exclude from window cycling
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle
        ]

        // Allow clicks, lasso selections, and drags to reach Finder
        self.ignoresMouseEvents = true
    }

    func updateFrameForScreen() {
        if let screen = targetScreen {
            self.setFrame(screen.frame, display: true)
        }
    }

    func setHidesDesktopIcons(_ hide: Bool) {
        self.hidesDesktopIcons = hide
        if hide {
            // Elevate above desktop icons layer: -2147483602
            self.level = NSWindow.Level(Int(CGWindowLevelForKey(.overlayWindow) + 1))
        } else {
            // Return behind desktop icons
            self.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
