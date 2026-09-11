#import "WallpaperLibraryWindowController.h"
#import "WallpaperManager.h"
#import <AVFoundation/AVFoundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

static NSCache<NSURL *, NSImage *> *sThumbnailCache = nil;

#pragma mark - Helper: Prettify Filename

static NSString *PrettifyWallpaperTitle(NSString *fileName) {
    NSString *name = [fileName stringByDeletingPathExtension];
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    name = [name stringByReplacingOccurrencesOfString:@"-" withString:@" "];
    
    // Capitalize words
    return [name capitalizedString];
}

#pragma mark - WallpaperCardView

@interface WallpaperCardView : NSView {
    NSImageView *_thumbnailView;
    NSTextField *_titleLabel;
    NSView *_badgeBackground;
    NSTextField *_badgeLabel;
    NSButton *_deleteButton;
    NSTrackingArea *_trackingArea;
    BOOL _isHovered;
}

@property (nonatomic, strong) NSURL *wallpaperURL;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isUserWallpaper;
@property (nonatomic, copy) void (^onSelect)(NSURL *url);
@property (nonatomic, copy) void (^onDelete)(NSURL *url);

- (instancetype)initWithWallpaperURL:(NSURL *)url
                            isActive:(BOOL)isActive
                     isUserWallpaper:(BOOL)isUserWallpaper;
- (void)updateActiveState:(BOOL)isActive;

@end

@implementation WallpaperCardView

- (instancetype)initWithWallpaperURL:(NSURL *)url
                            isActive:(BOOL)isActive
                     isUserWallpaper:(BOOL)isUserWallpaper {
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        _wallpaperURL = url;
        _isActive = isActive;
        _isUserWallpaper = isUserWallpaper;

        self.wantsLayer = YES;
        self.layer.cornerRadius = 10.0;
        self.layer.masksToBounds = YES;

        [self setupSubviews];
        [self updateBorders];
        [self loadThumbnail];
    }
    return self;
}

- (void)setupSubviews {
    // 1. Thumbnail
    _thumbnailView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    _thumbnailView.imageScaling = NSImageScaleAxesIndependently;
    _thumbnailView.wantsLayer = YES;
    _thumbnailView.layer.cornerRadius = 8.0;
    _thumbnailView.layer.masksToBounds = YES;
    _thumbnailView.layer.backgroundColor = [NSColor colorWithWhite:0.1 alpha:0.8].CGColor;
    [self addSubview:_thumbnailView];

    // 2. Title Label
    _titleLabel = [NSTextField labelWithString:PrettifyWallpaperTitle(_wallpaperURL.lastPathComponent)];
    _titleLabel.font = [NSFont systemFontOfSize:13.0 weight:NSFontWeightMedium];
    _titleLabel.textColor = [NSColor whiteColor];
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    _titleLabel.alignment = NSTextAlignmentLeft;
    [self addSubview:_titleLabel];

    // 3. Active Badge View
    _badgeBackground = [[NSView alloc] initWithFrame:NSZeroRect];
    _badgeBackground.wantsLayer = YES;
    _badgeBackground.layer.cornerRadius = 4.0;
    _badgeBackground.layer.backgroundColor = [NSColor colorWithSRGBRed:0.18 green:0.62 blue:0.95 alpha:0.95].CGColor;
    [self addSubview:_badgeBackground];

    _badgeLabel = [NSTextField labelWithString:@"✓ ACTIVE"];
    _badgeLabel.font = [NSFont systemFontOfSize:10.0 weight:NSFontWeightBold];
    _badgeLabel.textColor = [NSColor whiteColor];
    _badgeLabel.alignment = NSTextAlignmentCenter;
    [_badgeBackground addSubview:_badgeLabel];
    _badgeBackground.hidden = !_isActive;

    // 4. Delete button for custom user wallpapers
    if (_isUserWallpaper) {
        _deleteButton = [[NSButton alloc] initWithFrame:NSZeroRect];
        _deleteButton.bezelStyle = NSBezelStyleInline;
        _deleteButton.bordered = NO;
        _deleteButton.wantsLayer = YES;
        _deleteButton.layer.cornerRadius = 10.0;
        _deleteButton.layer.backgroundColor = [NSColor colorWithWhite:0.0 alpha:0.6].CGColor;
        NSImage *trashIcon = [NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Delete Wallpaper"];
        if (trashIcon) {
            _deleteButton.image = trashIcon;
            _deleteButton.contentTintColor = [NSColor colorWithWhite:0.9 alpha:0.9];
        } else {
            _deleteButton.title = @"✕";
        }
        _deleteButton.target = self;
        _deleteButton.action = @selector(deleteAction:);
        _deleteButton.toolTip = @"Remove from Library";
        [self addSubview:_deleteButton];
    }
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_trackingArea) {
        [self removeTrackingArea:_trackingArea];
    }
    NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect;
    _trackingArea = [[NSTrackingArea alloc] initWithRect:self.bounds options:options owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)event {
    _isHovered = YES;
    [self updateBorders];
}

- (void)mouseExited:(NSEvent *)event {
    _isHovered = NO;
    [self updateBorders];
}

- (void)mouseDown:(NSEvent *)event {
    if (self.onSelect) {
        self.onSelect(_wallpaperURL);
    }
}

- (void)deleteAction:(id)sender {
    if (self.onDelete) {
        self.onDelete(_wallpaperURL);
    }
}

- (void)updateActiveState:(BOOL)isActive {
    _isActive = isActive;
    _badgeBackground.hidden = !isActive;
    [self updateBorders];
}

- (void)updateBorders {
    self.layer.backgroundColor = [NSColor colorWithWhite:0.14 alpha:0.75].CGColor;
    if (_isActive) {
        self.layer.borderColor = [NSColor colorWithSRGBRed:0.2 green:0.65 blue:1.0 alpha:1.0].CGColor;
        self.layer.borderWidth = 2.0;
    } else if (_isHovered) {
        self.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.4].CGColor;
        self.layer.borderWidth = 1.5;
    } else {
        self.layer.borderColor = [NSColor colorWithWhite:1.0 alpha:0.12].CGColor;
        self.layer.borderWidth = 1.0;
    }
}

- (BOOL)isFlipped {
    return YES;
}

- (void)layout {
    [super layout];
    NSRect b = self.bounds;
    if (b.size.width <= 0 || b.size.height <= 0) return;

    CGFloat thumbMargin = 8.0;
    CGFloat thumbWidth = b.size.width - (thumbMargin * 2.0);
    CGFloat thumbHeight = thumbWidth * 9.0 / 16.0;
    _thumbnailView.frame = NSMakeRect(thumbMargin, thumbMargin, thumbWidth, thumbHeight);

    // Title label
    CGFloat labelY = thumbMargin + thumbHeight + 6.0;
    _titleLabel.frame = NSMakeRect(thumbMargin + 4.0, labelY, thumbWidth - 8.0, 20.0);

    // Active badge at top right corner of thumbnail
    CGFloat badgeW = 68.0;
    CGFloat badgeH = 20.0;
    _badgeBackground.frame = NSMakeRect(NSMaxX(_thumbnailView.frame) - badgeW - 6.0,
                                        NSMinY(_thumbnailView.frame) + 6.0,
                                        badgeW,
                                        badgeH);
    _badgeLabel.frame = _badgeBackground.bounds;

    // Delete button at top left corner of thumbnail
    if (_deleteButton) {
        CGFloat delSize = 22.0;
        _deleteButton.frame = NSMakeRect(NSMinX(_thumbnailView.frame) + 6.0,
                                         NSMinY(_thumbnailView.frame) + 6.0,
                                         delSize,
                                         delSize);
    }
}

- (void)loadThumbnail {
    if (!sThumbnailCache) {
        sThumbnailCache = [[NSCache alloc] init];
        sThumbnailCache.countLimit = 64;
    }

    NSImage *cached = [sThumbnailCache objectForKey:_wallpaperURL];
    if (cached) {
        _thumbnailView.image = cached;
        return;
    }

    // Generate asynchronous thumbnail
    NSURL *targetURL = _wallpaperURL;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:targetURL options:nil];
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.maximumSize = CGSizeMake(540, 304); // Crisp 16:9 thumbnail
        CMTime time = CMTimeMakeWithSeconds(1.0, 600);

        NSError *error = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
#pragma clang diagnostic pop

        if (!imageRef && error) {
            // Fallback to start of video
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
#pragma clang diagnostic pop
        }

        if (imageRef) {
            NSImage *thumbImage = [[NSImage alloc] initWithCGImage:imageRef size:NSMakeSize(CGImageGetWidth(imageRef), CGImageGetHeight(imageRef))];
            CGImageRelease(imageRef);

            [sThumbnailCache setObject:thumbImage forKey:targetURL];

            dispatch_async(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if (strongSelf && [strongSelf.wallpaperURL isEqual:targetURL]) {
                    strongSelf->_thumbnailView.image = thumbImage;
                }
            });
        }
    });
}

@end

#pragma mark - WallpaperGridView

@interface WallpaperGridView : NSView
@property (nonatomic, strong) NSArray<WallpaperCardView *> *cards;
@end

@implementation WallpaperGridView

- (BOOL)isFlipped {
    return YES;
}

- (void)setCards:(NSArray<WallpaperCardView *> *)cards {
    for (NSView *sub in self.subviews) {
        [sub removeFromSuperview];
    }
    _cards = [cards copy];
    for (WallpaperCardView *card in _cards) {
        [self addSubview:card];
    }
    [self layoutGrid];
}

- (void)layout {
    [super layout];
    [self layoutGrid];
}

- (void)layoutGrid {
    CGFloat totalWidth = self.bounds.size.width;
    if (totalWidth <= 0) return;

    CGFloat padding = 20.0;
    CGFloat spacing = 16.0;
    CGFloat minCardWidth = 210.0;

    CGFloat availableWidth = totalWidth - (padding * 2.0);
    NSInteger columns = (NSInteger)floor((availableWidth + spacing) / (minCardWidth + spacing));
    if (columns < 1) columns = 1;
    if (columns > 4) columns = 4;

    CGFloat cardWidth = (availableWidth - ((columns - 1) * spacing)) / columns;
    CGFloat thumbHeight = (cardWidth - 16.0) * 9.0 / 16.0;
    CGFloat cardHeight = thumbHeight + 16.0 + 36.0; // thumbnail + margins + title footer

    NSInteger count = _cards.count;
    NSInteger rows = (count + columns - 1) / columns;

    for (NSInteger i = 0; i < count; i++) {
        NSInteger row = i / columns;
        NSInteger col = i % columns;

        CGFloat x = padding + col * (cardWidth + spacing);
        CGFloat y = padding + row * (cardHeight + spacing);

        WallpaperCardView *card = _cards[i];
        card.frame = NSMakeRect(x, y, cardWidth, cardHeight);
    }

    CGFloat totalHeight = padding + rows * (cardHeight + spacing) + padding;
    if (totalHeight < self.enclosingScrollView.bounds.size.height) {
        totalHeight = self.enclosingScrollView.bounds.size.height;
    }

    if (fabs(self.frame.size.height - totalHeight) > 1.0) {
        [self setFrameSize:NSMakeSize(totalWidth, totalHeight)];
    }
}

@end

@interface WallpaperLibraryHeaderView : NSView
@end

@implementation WallpaperLibraryHeaderView
- (BOOL)isFlipped {
    return YES;
}
@end

#pragma mark - WallpaperLibraryWindowController

@interface WallpaperLibraryWindowController () <NSWindowDelegate> {
    NSVisualEffectView *_visualEffectView;
    NSScrollView *_scrollView;
    WallpaperGridView *_gridView;
    NSTextField *_statusLabel;
}
@end

@implementation WallpaperLibraryWindowController

+ (instancetype)sharedController {
    static WallpaperLibraryWindowController *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WallpaperLibraryWindowController alloc] init];
    });
    return instance;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 780, 520);
    NSWindowStyleMask style = NSWindowStyleMaskTitled |
                              NSWindowStyleMaskClosable |
                              NSWindowStyleMaskMiniaturizable |
                              NSWindowStyleMaskResizable |
                              NSWindowStyleMaskFullSizeContentView;

    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:style
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    win.title = @"Wallpaper Library";
    win.titlebarAppearsTransparent = YES;
    win.titleVisibility = NSWindowTitleHidden;
    win.minSize = NSMakeSize(560, 400);
    win.releasedWhenClosed = NO;
    win.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [win center];

    self = [super initWithWindow:win];
    if (self) {
        win.delegate = self;
        [self setupUI];
        [self reloadWallpapers];

        // Observe external wallpaper changes
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(wallpaperDidChange:)
                                                     name:AuraWallpaperDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    NSWindow *win = self.window;

    // 1. Vibrant backdrop
    _visualEffectView = [[NSVisualEffectView alloc] initWithFrame:win.contentView.bounds];
    _visualEffectView.material = NSVisualEffectMaterialUnderWindowBackground;
    _visualEffectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _visualEffectView.state = NSVisualEffectStateActive;
    _visualEffectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    win.contentView = _visualEffectView;

    // 2. Header view (top 70pt, flipped coordinates)
    CGFloat headerHeight = 70.0;
    NSRect headerFrame = NSMakeRect(0, win.contentView.bounds.size.height - headerHeight, win.contentView.bounds.size.width, headerHeight);
    WallpaperLibraryHeaderView *headerView = [[WallpaperLibraryHeaderView alloc] initWithFrame:headerFrame];
    headerView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [_visualEffectView addSubview:headerView];

    // Header icon (clear of traffic lights at x=84)
    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSMakeRect(84.0, 14.0, 24.0, 24.0)];
    NSImage *symbolImg = [NSImage imageWithSystemSymbolName:@"sparkles.tv" accessibilityDescription:@"Library Icon"];
    if (!symbolImg) {
        symbolImg = [NSImage imageWithSystemSymbolName:@"display" accessibilityDescription:@"Library Icon"];
    }
    iconView.image = symbolImg;
    iconView.contentTintColor = [NSColor colorWithSRGBRed:0.25 green:0.68 blue:1.0 alpha:1.0];
    [headerView addSubview:iconView];

    // Header Title & Subtitle aligned cleanly at x=116
    NSTextField *titleLabel = [NSTextField labelWithString:@"Wallpaper Library"];
    titleLabel.font = [NSFont systemFontOfSize:17.0 weight:NSFontWeightBold];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.frame = NSMakeRect(116.0, 12.0, 280.0, 24.0);
    [headerView addSubview:titleLabel];

    _statusLabel = [NSTextField labelWithString:@"Select a dynamic wallpaper to apply to your desktop"];
    _statusLabel.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightRegular];
    _statusLabel.textColor = [NSColor colorWithWhite:0.65 alpha:1.0];
    _statusLabel.frame = NSMakeRect(116.0, 38.0, 420.0, 18.0);
    [headerView addSubview:_statusLabel];

    // "+ Add Wallpaper..." button
    NSButton *addButton = [[NSButton alloc] initWithFrame:NSMakeRect(headerView.bounds.size.width - 168.0, 18.0, 144.0, 32.0)];
    addButton.autoresizingMask = NSViewMinXMargin;
    addButton.bezelStyle = NSBezelStyleRounded;
    addButton.title = @"+ Add Wallpaper...";
    addButton.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
    addButton.target = self;
    addButton.action = @selector(addWallpaperAction:);
    [headerView addSubview:addButton];

    // Subtle divider line
    NSBox *divider = [[NSBox alloc] initWithFrame:NSMakeRect(0, headerHeight - 1.0, headerView.bounds.size.width, 1.0)];
    divider.boxType = NSBoxSeparator;
    divider.autoresizingMask = NSViewWidthSizable;
    [headerView addSubview:divider];

    // 3. Scroll view & Grid view
    NSRect scrollFrame = NSMakeRect(0, 0, win.contentView.bounds.size.width, win.contentView.bounds.size.height - headerHeight);
    _scrollView = [[NSScrollView alloc] initWithFrame:scrollFrame];
    _scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _scrollView.hasVerticalScroller = YES;
    _scrollView.hasHorizontalScroller = NO;
    _scrollView.drawsBackground = NO;

    _gridView = [[WallpaperGridView alloc] initWithFrame:NSMakeRect(0, 0, scrollFrame.size.width, scrollFrame.size.height)];
    _gridView.autoresizingMask = NSViewWidthSizable;
    _scrollView.documentView = _gridView;

    [_visualEffectView addSubview:_scrollView];
}

- (void)showLibrary {
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self reloadWallpapers];
}

- (void)wallpaperDidChange:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateActiveCards];
    });
}

- (void)updateActiveCards {
    NSURL *currentURL = [WallpaperManager sharedManager].currentVideoURL;
    for (WallpaperCardView *card in _gridView.cards) {
        BOOL isThisActive = [card.wallpaperURL.path isEqualToString:currentURL.path];
        [card updateActiveState:isThisActive];
    }
}

- (void)reloadWallpapers {
    NSArray<NSURL *> *wallpapers = [WallpaperManager allAvailableWallpapers];
    NSURL *currentURL = [WallpaperManager sharedManager].currentVideoURL;
    NSURL *userDir = [WallpaperManager userWallpapersDirectory];

    NSMutableArray<WallpaperCardView *> *cardViews = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;

    for (NSURL *url in wallpapers) {
        BOOL isActive = [url.path isEqualToString:currentURL.path];
        BOOL isUser = [url.path hasPrefix:userDir.path];

        WallpaperCardView *card = [[WallpaperCardView alloc] initWithWallpaperURL:url
                                                                         isActive:isActive
                                                                  isUserWallpaper:isUser];
        card.onSelect = ^(NSURL *selectedURL) {
            [[WallpaperManager sharedManager] setWallpaperVideoURL:selectedURL];
            [weakSelf updateActiveCards];
        };
        card.onDelete = ^(NSURL *deletedURL) {
            [weakSelf promptDeleteWallpaper:deletedURL];
        };
        [cardViews addObject:card];
    }

    _gridView.cards = cardViews;

    _statusLabel.stringValue = [NSString stringWithFormat:@"%lu wallpaper%@ available • Click any wallpaper to apply",
                                (unsigned long)wallpapers.count,
                                wallpapers.count == 1 ? @"" : @"s"];
}

- (void)promptDeleteWallpaper:(NSURL *)url {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Remove \"%@\"?", PrettifyWallpaperTitle(url.lastPathComponent)];
    alert.informativeText = @"This wallpaper will be removed from your AuraWallpaper library.";
    [alert addButtonWithTitle:@"Remove"];
    [alert addButtonWithTitle:@"Cancel"];
    alert.alertStyle = NSAlertStyleWarning;

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            NSError *err = nil;
            BOOL ok = [WallpaperManager deleteUserWallpaperAtURL:url error:&err];
            if (ok) {
                // If the deleted wallpaper was currently active, fall back to default
                if ([[WallpaperManager sharedManager].currentVideoURL.path isEqualToString:url.path]) {
                    [[WallpaperManager sharedManager] startWithDefaultOrSavedWallpaper];
                }
                [self reloadWallpapers];
            } else if (err) {
                NSAlert *errAlert = [NSAlert alertWithError:err];
                [errAlert beginSheetModalForWindow:self.window completionHandler:nil];
            }
        }
    }];
}

- (void)addWallpaperAction:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[
        [UTType typeWithFilenameExtension:@"mp4"],
        [UTType typeWithFilenameExtension:@"mov"],
        [UTType typeWithFilenameExtension:@"m4v"],
        [UTType typeWithFilenameExtension:@"webm"]
    ];
    panel.message = @"Select a video to add to your Wallpaper Library:";
    panel.prompt = @"Add to Library";

    [NSApp activateIgnoringOtherApps:YES];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL) {
            NSError *error = nil;
            NSURL *importedURL = [WallpaperManager importWallpaperAtURL:panel.URL error:&error];
            if (importedURL) {
                // Apply immediately
                [[WallpaperManager sharedManager] setWallpaperVideoURL:importedURL];
                [self reloadWallpapers];
            } else if (error) {
                NSAlert *errAlert = [NSAlert alertWithError:error];
                [errAlert beginSheetModalForWindow:self.window completionHandler:nil];
            }
        }
    }];
}

@end
