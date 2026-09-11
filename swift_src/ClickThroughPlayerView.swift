import Cocoa
import AVKit

/// Custom AVPlayerView that passes all mouse clicks directly through to Finder desktop icons
final class ClickThroughPlayerView: AVPlayerView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.controlsStyle = .none
        self.videoGravity = .resizeAspectFill
        self.updatesNowPlayingInfoCenter = false // Prevent hijacking media keys / Control Center
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.controlsStyle = .none
        self.videoGravity = .resizeAspectFill
        self.updatesNowPlayingInfoCenter = false
    }

    /// Returning nil ensures mouse events bypass this view and reach desktop icons
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}
