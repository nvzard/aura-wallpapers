import Cocoa
import AVFoundation
import UniformTypeIdentifiers

private var sThumbnailCache = NSCache<NSURL, NSImage>()

private func PrettifyWallpaperTitle(_ fileName: String) -> String {
    let base = (fileName as NSString).deletingPathExtension
    let spaced = base.replacingOccurrences(of: "_", with: " ")
                     .replacingOccurrences(of: "-", with: " ")
    return spaced.capitalized
}

// MARK: - WallpaperCardView

final class WallpaperCardView: NSView {
    let wallpaperURL: URL
    private(set) var isActive: Bool
    let isUserWallpaper: Bool

    var onSelect: ((URL) -> Void)?
    var onDelete: ((URL) -> Void)?

    private let thumbnailView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let badgeBackground = NSView()
    private let badgeLabel = NSTextField(labelWithString: "✓ ACTIVE")
    private var deleteButton: NSButton?
    private var trackingAreaRef: NSTrackingArea?
    private var isHovered = false

    init(wallpaperURL: URL, isActive: Bool, isUserWallpaper: Bool) {
        self.wallpaperURL = wallpaperURL
        self.isActive = isActive
        self.isUserWallpaper = isUserWallpaper
        super.init(frame: .zero)

        wantsLayer = true
        layer?.cornerRadius = 10.0
        layer?.masksToBounds = true

        setupSubviews()
        updateBorders()
        loadThumbnail()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        // Thumbnail
        thumbnailView.imageScaling = .scaleAxesIndependently
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 8.0
        thumbnailView.layer?.masksToBounds = true
        thumbnailView.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.8).cgColor
        addSubview(thumbnailView)

        // Title Label
        titleLabel.stringValue = PrettifyWallpaperTitle(wallpaperURL.lastPathComponent)
        titleLabel.font = .systemFont(ofSize: 13.0, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.alignment = .left
        addSubview(titleLabel)

        // Badge
        badgeBackground.wantsLayer = true
        badgeBackground.layer?.cornerRadius = 4.0
        badgeBackground.layer?.backgroundColor = NSColor(srgbRed: 0.18, green: 0.62, blue: 0.95, alpha: 0.95).cgColor
        addSubview(badgeBackground)

        badgeLabel.font = .systemFont(ofSize: 10.0, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.alignment = .center
        badgeBackground.addSubview(badgeLabel)
        badgeBackground.isHidden = !isActive

        // Delete button
        if isUserWallpaper {
            let btn = NSButton(frame: .zero)
            btn.bezelStyle = .inline
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 10.0
            btn.layer?.backgroundColor = NSColor(white: 0.0, alpha: 0.6).cgColor
            if let img = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Delete Wallpaper") {
                btn.image = img
                btn.contentTintColor = NSColor(white: 0.9, alpha: 0.9)
            } else {
                btn.title = "✕"
            }
            btn.target = self
            btn.action = #selector(deleteAction)
            btn.toolTip = "Remove from Library"
            addSubview(btn)
            deleteButton = btn
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let opts: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateBorders()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateBorders()
    }

    override func mouseDown(with event: NSEvent) {
        onSelect?(wallpaperURL)
    }

    @objc private func deleteAction() {
        onDelete?(wallpaperURL)
    }

    func updateActiveState(_ active: Bool) {
        isActive = active
        badgeBackground.isHidden = !active
        updateBorders()
    }

    private func updateBorders() {
        layer?.backgroundColor = NSColor(white: 0.14, alpha: 0.75).cgColor
        if isActive {
            layer?.borderColor = NSColor(srgbRed: 0.2, green: 0.65, blue: 1.0, alpha: 1.0).cgColor
            layer?.borderWidth = 2.0
        } else if isHovered {
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.4).cgColor
            layer?.borderWidth = 1.5
        } else {
            layer?.borderColor = NSColor(white: 1.0, alpha: 0.12).cgColor
            layer?.borderWidth = 1.0
        }
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let b = bounds
        guard b.width > 0, b.height > 0 else { return }

        let thumbMargin: CGFloat = 8.0
        let thumbWidth = b.width - (thumbMargin * 2.0)
        let thumbHeight = thumbWidth * 9.0 / 16.0
        thumbnailView.frame = NSRect(x: thumbMargin, y: thumbMargin, width: thumbWidth, height: thumbHeight)

        let labelY = thumbMargin + thumbHeight + 6.0
        titleLabel.frame = NSRect(x: thumbMargin + 4.0, y: labelY, width: thumbWidth - 8.0, height: 20.0)

        let badgeW: CGFloat = 68.0
        let badgeH: CGFloat = 20.0
        badgeBackground.frame = NSRect(x: thumbnailView.frame.maxX - badgeW - 6.0,
                                       y: thumbnailView.frame.minY + 6.0,
                                       width: badgeW,
                                       height: badgeH)
        badgeLabel.frame = badgeBackground.bounds

        if let del = deleteButton {
            let delSize: CGFloat = 22.0
            del.frame = NSRect(x: thumbnailView.frame.minX + 6.0,
                               y: thumbnailView.frame.minY + 6.0,
                               width: delSize,
                               height: delSize)
        }
    }

    private func loadThumbnail() {
        sThumbnailCache.countLimit = 64
        if let cached = sThumbnailCache.object(forKey: wallpaperURL as NSURL) {
            thumbnailView.image = cached
            return
        }

        let target = wallpaperURL
        DispatchQueue.global(qos: .default).async { [weak self] in
            let asset = AVURLAsset(url: target)
            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            gen.maximumSize = CGSize(width: 540, height: 304)

            let time = CMTime(seconds: 1.0, preferredTimescale: 600)
            var imageRef: CGImage?
            do {
                imageRef = try gen.copyCGImage(at: time, actualTime: nil)
            } catch {
                imageRef = try? gen.copyCGImage(at: .zero, actualTime: nil)
            }

            guard let img = imageRef else { return }
            let thumb = NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))
            sThumbnailCache.setObject(thumb, forKey: target as NSURL)

            DispatchQueue.main.async {
                guard let self = self, self.wallpaperURL == target else { return }
                self.thumbnailView.image = thumb
            }
        }
    }
}

// MARK: - WallpaperGridView

final class WallpaperGridView: NSView {
    override var isFlipped: Bool { true }

    var cards: [WallpaperCardView] = [] {
        didSet {
            subviews.forEach { $0.removeFromSuperview() }
            cards.forEach { addSubview($0) }
            layoutGrid()
        }
    }

    override func layout() {
        super.layout()
        layoutGrid()
    }

    private func layoutGrid() {
        let totalWidth = bounds.width
        guard totalWidth > 0 else { return }

        let padding: CGFloat = 20.0
        let spacing: CGFloat = 16.0
        let minCardWidth: CGFloat = 210.0

        let availableWidth = totalWidth - (padding * 2.0)
        var columns = Int(floor((availableWidth + spacing) / (minCardWidth + spacing)))
        if columns < 1 { columns = 1 }
        if columns > 4 { columns = 4 }

        let cardWidth = (availableWidth - (CGFloat(columns - 1) * spacing)) / CGFloat(columns)
        let thumbHeight = (cardWidth - 16.0) * 9.0 / 16.0
        let cardHeight = thumbHeight + 16.0 + 36.0

        let count = cards.count
        let rows = (count + columns - 1) / columns

        for (i, card) in cards.enumerated() {
            let row = i / columns
            let col = i % columns

            let x = padding + CGFloat(col) * (cardWidth + spacing)
            let y = padding + CGFloat(row) * (cardHeight + spacing)

            card.frame = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
        }

        var totalHeight = padding + CGFloat(rows) * (cardHeight + spacing) + padding
        if let scrollH = enclosingScrollView?.bounds.height, totalHeight < scrollH {
            totalHeight = scrollH
        }

        if abs(frame.height - totalHeight) > 1.0 {
            setFrameSize(NSSize(width: totalWidth, height: totalHeight))
        }
    }
}

// MARK: - WallpaperLibraryWindowController

private final class WallpaperLibraryHeaderView: NSView {
    override var isFlipped: Bool { true }
}

final class WallpaperLibraryWindowController: NSWindowController, NSWindowDelegate {
    static let shared = WallpaperLibraryWindowController()

    private var visualEffectView: NSVisualEffectView!
    private var scrollView: NSScrollView!
    private var gridView: WallpaperGridView!
    private var statusLabel: NSTextField!

    convenience init() {
        let rect = NSRect(x: 0, y: 0, width: 780, height: 520)
        let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let win = NSWindow(contentRect: rect, styleMask: style, backing: .buffered, defer: false)
        win.title = "Wallpaper Library"
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.minSize = NSSize(width: 560, height: 400)
        win.isReleasedWhenClosed = false
        win.appearance = NSAppearance(named: .darkAqua)
        win.center()

        self.init(window: win)
        win.delegate = self
        setupUI()
        reloadWallpapers()

        NotificationCenter.default.addObserver(
            forName: WallpaperManager.didChangeWallpaperNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateActiveCards()
        }
    }

    private func setupUI() {
        guard let win = window else { return }

        // Vibrant backdrop
        visualEffectView = NSVisualEffectView(frame: win.contentView!.bounds)
        visualEffectView.material = .underWindowBackground
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.autoresizingMask = [.width, .height]
        win.contentView = visualEffectView

        // Header view (top 70pt, flipped coordinates)
        let headerHeight: CGFloat = 70.0
        let headerFrame = NSRect(x: 0, y: win.contentView!.bounds.height - headerHeight, width: win.contentView!.bounds.width, height: headerHeight)
        let headerView = WallpaperLibraryHeaderView(frame: headerFrame)
        headerView.autoresizingMask = [.width, .minYMargin]
        visualEffectView.addSubview(headerView)

        // Header icon (clear of traffic lights at x=84)
        let iconView = NSImageView(frame: NSRect(x: 84.0, y: 14.0, width: 24.0, height: 24.0))
        let symbol = NSImage(systemSymbolName: "sparkles.tv", accessibilityDescription: "Library Icon") ??
                     NSImage(systemSymbolName: "display", accessibilityDescription: "Library Icon")
        iconView.image = symbol
        iconView.contentTintColor = NSColor(srgbRed: 0.25, green: 0.68, blue: 1.0, alpha: 1.0)
        headerView.addSubview(iconView)

        // Header Title & Subtitle aligned cleanly at x=116
        let titleLabel = NSTextField(labelWithString: "Wallpaper Library")
        titleLabel.font = .systemFont(ofSize: 17.0, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.frame = NSRect(x: 116.0, y: 12.0, width: 280.0, height: 24.0)
        headerView.addSubview(titleLabel)

        statusLabel = NSTextField(labelWithString: "Select a dynamic wallpaper to apply to your desktop")
        statusLabel.font = .systemFont(ofSize: 11.5, weight: .regular)
        statusLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        statusLabel.frame = NSRect(x: 116.0, y: 38.0, width: 420.0, height: 18.0)
        headerView.addSubview(statusLabel)

        let addButton = NSButton(frame: NSRect(x: headerView.bounds.width - 168.0, y: 18.0, width: 144.0, height: 32.0))
        addButton.autoresizingMask = .minXMargin
        addButton.bezelStyle = .rounded
        addButton.title = "+ Add Wallpaper..."
        addButton.font = .systemFont(ofSize: 12.5, weight: .semibold)
        addButton.target = self
        addButton.action = #selector(addWallpaperAction)
        headerView.addSubview(addButton)

        let divider = NSBox(frame: NSRect(x: 0, y: headerHeight - 1.0, width: headerView.bounds.width, height: 1.0))
        divider.boxType = .separator
        divider.autoresizingMask = .width
        headerView.addSubview(divider)

        // Scroll & Grid view
        let scrollFrame = NSRect(x: 0, y: 0, width: win.contentView!.bounds.width, height: win.contentView!.bounds.height - headerHeight)
        scrollView = NSScrollView(frame: scrollFrame)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        gridView = WallpaperGridView(frame: NSRect(x: 0, y: 0, width: scrollFrame.width, height: scrollFrame.height))
        gridView.autoresizingMask = .width
        scrollView.documentView = gridView

        visualEffectView.addSubview(scrollView)
    }

    func showLibrary() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        reloadWallpapers()
    }

    private func updateActiveCards() {
        let currentURL = WallpaperManager.shared.currentVideoURL
        for card in gridView.cards {
            let isThisActive = card.wallpaperURL.path == currentURL?.path
            card.updateActiveState(isThisActive)
        }
    }

    func reloadWallpapers() {
        let wallpapers = WallpaperManager.allAvailableWallpapers()
        let currentURL = WallpaperManager.shared.currentVideoURL
        let userDir = WallpaperManager.userWallpapersDirectory

        var cardViews: [WallpaperCardView] = []
        for url in wallpapers {
            let isActive = url.path == currentURL?.path
            let isUser = url.path.hasPrefix(userDir.path)

            let card = WallpaperCardView(wallpaperURL: url, isActive: isActive, isUserWallpaper: isUser)
            card.onSelect = { [weak self] selectedURL in
                WallpaperManager.shared.setWallpaper(url: selectedURL)
                self?.updateActiveCards()
            }
            card.onDelete = { [weak self] deletedURL in
                self?.promptDeleteWallpaper(deletedURL)
            }
            cardViews.append(card)
        }

        gridView.cards = cardViews
        statusLabel.stringValue = "\(wallpapers.count) wallpaper\(wallpapers.count == 1 ? "" : "s") available • Click any wallpaper to apply"
    }

    private func promptDeleteWallpaper(_ url: URL) {
        guard let win = window else { return }
        let alert = NSAlert()
        alert.messageText = "Remove \"\(PrettifyWallpaperTitle(url.lastPathComponent))\"?"
        alert.informativeText = "This wallpaper will be removed from your AuraWallpaper library."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        alert.beginSheetModal(for: win) { [weak self] response in
            if response == .alertFirstButtonReturn {
                do {
                    try WallpaperManager.deleteUserWallpaper(at: url)
                    if WallpaperManager.shared.currentVideoURL?.path == url.path {
                        WallpaperManager.shared.startWithDefaultOrSavedWallpaper()
                    }
                    self?.reloadWallpapers()
                } catch {
                    let errAlert = NSAlert(error: error)
                    errAlert.beginSheetModal(for: win, completionHandler: nil)
                }
            }
        }
    }

    @objc private func addWallpaperAction() {
        guard let win = window else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.message = "Select a video to add to your Wallpaper Library:"
        panel.prompt = "Add to Library"

        NSApp.activate(ignoringOtherApps: true)
        panel.beginSheetModal(for: win) { [weak self] response in
            if response == .OK, let selectedURL = panel.url {
                do {
                    let importedURL = try WallpaperManager.importWallpaper(at: selectedURL)
                    WallpaperManager.shared.setWallpaper(url: importedURL)
                    self?.reloadWallpapers()
                } catch {
                    let errAlert = NSAlert(error: error)
                    errAlert.beginSheetModal(for: win, completionHandler: nil)
                }
            }
        }
    }
}
