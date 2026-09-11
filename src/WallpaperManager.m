#import "WallpaperManager.h"

static NSString * const kSavedWallpaperPathKey = @"AuraWallpaperSavedPath";
static NSString * const kSavedMutedKey = @"AuraWallpaperMuted";
static NSString * const kSavedVolumeKey = @"AuraWallpaperVolume";
static NSString * const kSavedHideIconsKey = @"AuraWallpaperHideIcons";

@interface WallpaperManager () {
    NSMutableArray<WallpaperWindow *> *_windows;
    BOOL _isSleep;
}
@end

@implementation WallpaperManager

+ (instancetype)sharedManager {
    static WallpaperManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WallpaperManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _windows = [NSMutableArray array];
        _isSleep = NO;
        _isPlaying = YES;

        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        _isMuted = [defs objectForKey:kSavedMutedKey] ? [defs boolForKey:kSavedMutedKey] : YES;
        _volume = [defs objectForKey:kSavedVolumeKey] ? [defs floatForKey:kSavedVolumeKey] : 0.0f;
        _hidesDesktopIcons = [defs boolForKey:kSavedHideIconsKey];

        [self setupObservers];
    }
    return self;
}

- (void)setupObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSNotificationCenter *wsCenter = [[NSWorkspace sharedWorkspace] notificationCenter];

    // Screen configuration changes (resolution, connect/disconnect monitor)
    [center addObserver:self
               selector:@selector(screenParametersChanged:)
                   name:NSApplicationDidChangeScreenParametersNotification
                 object:nil];

    // Sleep / Wake power notifications
    [wsCenter addObserver:self
                 selector:@selector(screensDidSleep:)
                     name:NSWorkspaceScreensDidSleepNotification
                   object:nil];

    [wsCenter addObserver:self
                 selector:@selector(screensDidWake:)
                     name:NSWorkspaceScreensDidWakeNotification
                   object:nil];

    // Space changes
    [wsCenter addObserver:self
                 selector:@selector(activeSpaceDidChange:)
                     name:NSWorkspaceActiveSpaceDidChangeNotification
                   object:nil];
}

- (void)startWithDefaultOrSavedWallpaper {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *savedPath = [defs stringForKey:kSavedWallpaperPathKey];

    if (savedPath && [[NSFileManager defaultManager] fileExistsAtPath:savedPath]) {
        [self setWallpaperVideoURL:[NSURL fileURLWithPath:savedPath]];
        return;
    }

    // Use bundled default wallpaper if available
    NSString *bundledPath = [[NSBundle mainBundle] pathForResource:@"default_wallpaper" ofType:@"mp4"];
    if (bundledPath && [[NSFileManager defaultManager] fileExistsAtPath:bundledPath]) {
        [self setWallpaperVideoURL:[NSURL fileURLWithPath:bundledPath]];
        return;
    }

    // Check application resources or assets
    NSString *resourcePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"default_wallpaper.mp4"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:resourcePath]) {
        [self setWallpaperVideoURL:[NSURL fileURLWithPath:resourcePath]];
    }
}

- (void)setWallpaperVideoURL:(NSURL *)url {
    if (!url) return;
    _currentVideoURL = url;
    _isPlaying = YES;

    [[NSUserDefaults standardUserDefaults] setObject:url.path forKey:kSavedWallpaperPathKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [self rebuildWindows];
}

- (void)rebuildWindows {
    // Close existing windows
    for (WallpaperWindow *window in _windows) {
        [window close];
    }
    [_windows removeAllObjects];

    if (!_currentVideoURL) return;

    NSArray<NSScreen *> *screens = [NSScreen screens];
    for (NSScreen *screen in screens) {
        WallpaperWindow *window = [[WallpaperWindow alloc] initWithScreen:screen];
        WallpaperViewController *vc = [[WallpaperViewController alloc] init];
        vc.isMuted = _isMuted;
        vc.volume = _volume;

        window.contentViewController = vc;
        [window setHidesDesktopIcons:_hidesDesktopIcons];

        // Ensure window frame covers the full screen bounds
        [window setFrame:screen.frame display:YES];
        [window orderFront:nil];

        [vc loadVideoURL:_currentVideoURL forScreen:screen];

        if (!_isPlaying || _isSleep) {
            [vc pause];
        }

        [_windows addObject:window];
    }
}

#pragma mark - Playback Controls

- (void)playAll {
    _isPlaying = YES;
    for (WallpaperWindow *w in _windows) {
        WallpaperViewController *vc = (WallpaperViewController *)w.contentViewController;
        [vc play];
    }
}

- (void)pauseAll {
    _isPlaying = NO;
    for (WallpaperWindow *w in _windows) {
        WallpaperViewController *vc = (WallpaperViewController *)w.contentViewController;
        [vc pause];
    }
}

- (void)togglePlayPause {
    if (_isPlaying) {
        [self pauseAll];
    } else {
        [self playAll];
    }
}

- (void)setMuted:(BOOL)muted {
    _isMuted = muted;
    [[NSUserDefaults standardUserDefaults] setBool:muted forKey:kSavedMutedKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    for (WallpaperWindow *w in _windows) {
        WallpaperViewController *vc = (WallpaperViewController *)w.contentViewController;
        [vc setMuted:muted];
    }
}

- (void)setVolume:(float)volume {
    _volume = volume;
    [[NSUserDefaults standardUserDefaults] setFloat:volume forKey:kSavedVolumeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    for (WallpaperWindow *w in _windows) {
        WallpaperViewController *vc = (WallpaperViewController *)w.contentViewController;
        [vc setVolume:volume];
    }
}

- (void)setHideDesktopIcons:(BOOL)hide {
    _hidesDesktopIcons = hide;
    [[NSUserDefaults standardUserDefaults] setBool:hide forKey:kSavedHideIconsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    for (WallpaperWindow *w in _windows) {
        [w setHidesDesktopIcons:hide];
    }
}

#pragma mark - Notifications

- (void)screenParametersChanged:(NSNotification *)note {
    // Displays reconfigured, rebuild to assign exact windows to each screen
    [self rebuildWindows];
}

- (void)screensDidSleep:(NSNotification *)note {
    _isSleep = YES;
    for (WallpaperWindow *w in _windows) {
        WallpaperViewController *vc = (WallpaperViewController *)w.contentViewController;
        [vc pause];
    }
}

- (void)screensDidWake:(NSNotification *)note {
    _isSleep = NO;
    if (_isPlaying) {
        for (WallpaperWindow *w in _windows) {
            WallpaperViewController *vc = (WallpaperViewController *)w.contentViewController;
            [vc play];
        }
    }
}

- (void)activeSpaceDidChange:(NSNotification *)note {
    for (WallpaperWindow *w in _windows) {
        [w updateFrameForScreen];
    }
}

@end
