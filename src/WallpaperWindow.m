#import "WallpaperWindow.h"

@implementation WallpaperWindow

- (instancetype)initWithScreen:(NSScreen *)screen {
    self = [super initWithContentRect:screen.frame
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:NO
                               screen:screen];
    if (self) {
        _targetScreen = screen;
        _hidesDesktopIcons = NO;

        self.opaque = NO;
        self.backgroundColor = [NSColor clearColor];
        self.hasShadow = NO;
        self.animationBehavior = NSWindowAnimationBehaviorNone;

        // Position behind desktop icons by default
        self.level = CGWindowLevelForKey(kCGDesktopWindowLevelKey);

        // Keep on all spaces, stationary during Mission Control, ignore Cmd-Tab
        self.collectionBehavior = (NSWindowCollectionBehaviorCanJoinAllSpaces |
                                   NSWindowCollectionBehaviorStationary |
                                   NSWindowCollectionBehaviorIgnoresCycle);

        // Allow clicks to pass through to desktop icons
        self.ignoresMouseEvents = YES;
    }
    return self;
}

- (void)updateFrameForScreen {
    if (self.targetScreen) {
        [self setFrame:self.targetScreen.frame display:YES];
    }
}

- (void)setHidesDesktopIcons:(BOOL)hide {
    _hidesDesktopIcons = hide;
    if (hide) {
        // Elevate above desktop icons layer
        self.level = CGWindowLevelForKey(kCGOverlayWindowLevelKey) + 1;
    } else {
        // Return behind desktop icons
        self.level = CGWindowLevelForKey(kCGDesktopWindowLevelKey);
    }
}

// Ensure the window cannot become key or main window
- (BOOL)canBecomeKeyWindow {
    return NO;
}

- (BOOL)canBecomeMainWindow {
    return NO;
}

@end
