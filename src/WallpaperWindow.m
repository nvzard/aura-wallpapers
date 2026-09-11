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
        self.releasedWhenClosed = NO;

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

- (void)setLevel:(NSWindowLevel)newLevel {
    // Safety guard: Live wallpaper must NEVER be elevated to or above normal application window level (0).
    // An elevated level would cover user windows and render macOS completely unusable.
    if (newLevel >= CGWindowLevelForKey(kCGNormalWindowLevelKey)) {
        NSLog(@"[WallpaperWindow] ERROR: Refusing unsafe window level %ld (must be below normal window level 0)", (long)newLevel);
        newLevel = CGWindowLevelForKey(kCGDesktopWindowLevelKey);
    }
    [super setLevel:newLevel];
}

- (void)setHidesDesktopIcons:(BOOL)hide {
    _hidesDesktopIcons = hide;
    if (hide) {
        // Elevate above desktop icons (-2147483603) and WindowServer underbelly (-2147483602) layers (-1),
        // strictly below normal application windows (0) to eliminate menu bar fade flickering.
        self.level = CGWindowLevelForKey(kCGNormalWindowLevelKey) - 1;
    } else {
        // Return behind desktop icons (-2147483623)
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
