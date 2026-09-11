#import "WallpaperManager.h"

NSString * const AuraWallpaperDidChangeNotification = @"AuraWallpaperDidChangeNotification";

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

    NSArray<NSScreen *> *screens = [NSScreen screens];
    BOOL canReuse = (_windows.count == screens.count && _windows.count > 0);
    if (canReuse) {
        for (WallpaperWindow *window in _windows) {
            if (!window.targetScreen || ![screens containsObject:window.targetScreen]) {
                canReuse = NO;
                break;
            }
        }
    }

    if (canReuse) {
        for (WallpaperWindow *window in _windows) {
            WallpaperViewController *vc = (WallpaperViewController *)window.contentViewController;
            [vc loadVideoURL:_currentVideoURL forScreen:window.targetScreen];
            if (!_isPlaying || _isSleep) {
                [vc pause];
            }
            [window orderFront:nil];
        }
    } else {
        [self rebuildWindows];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:AuraWallpaperDidChangeNotification
                                                        object:self
                                                      userInfo:@{@"url": url}];
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

#pragma mark - Wallpaper Library Helpers

+ (NSURL *)userWallpapersDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *appSupport = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [appSupport URLByAppendingPathComponent:@"AuraWallpaper/Wallpapers" isDirectory:YES];
    if (![fm fileExistsAtPath:dir.path]) {
        [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return dir;
}

+ (NSArray<NSURL *> *)allAvailableWallpapers {
    NSMutableArray<NSURL *> *results = [NSMutableArray array];
    NSMutableSet<NSString *> *seenFileNames = [NSMutableSet set];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *validExtensions = @[@"mp4", @"mov", @"m4v", @"webm"];

    // 1. Bundled wallpapers in Resources
    NSURL *bundleResURL = [[NSBundle mainBundle] resourceURL];
    if (bundleResURL) {
        NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:bundleResURL
                                       includingPropertiesForKeys:nil
                                                          options:NSDirectoryEnumerationSkipsHiddenFiles
                                                            error:NULL];
        for (NSURL *fileURL in contents) {
            NSString *ext = fileURL.pathExtension.lowercaseString;
            NSString *name = fileURL.lastPathComponent.lowercaseString;
            if ([validExtensions containsObject:ext] && ![seenFileNames containsObject:name]) {
                [seenFileNames addObject:name];
                [results addObject:fileURL];
            }
        }
    }

    // Fallback if running outside of an .app bundle (e.g. CLI tool tests)
    if (results.count == 0) {
        NSString *devAssetsPath = @"assets";
        if ([fm fileExistsAtPath:devAssetsPath]) {
            NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:devAssetsPath error:NULL];
            for (NSString *file in files) {
                NSString *ext = file.pathExtension.lowercaseString;
                NSString *name = file.lowercaseString;
                if ([validExtensions containsObject:ext] && ![seenFileNames containsObject:name]) {
                    NSString *full = [devAssetsPath stringByAppendingPathComponent:file];
                    [seenFileNames addObject:name];
                    [results addObject:[NSURL fileURLWithPath:[full stringByStandardizingPath]]];
                }
            }
        }
    }

    // 2. User library wallpapers
    NSURL *userDir = [self userWallpapersDirectory];
    NSArray<NSURL *> *userFiles = [fm contentsOfDirectoryAtURL:userDir
                                    includingPropertiesForKeys:nil
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         error:NULL];
    for (NSURL *fileURL in userFiles) {
        NSString *ext = fileURL.pathExtension.lowercaseString;
        NSString *name = fileURL.lastPathComponent.lowercaseString;
        if ([validExtensions containsObject:ext] && ![seenFileNames containsObject:name]) {
            [seenFileNames addObject:name];
            [results addObject:fileURL];
        }
    }

    // 3. Current active wallpaper if not yet in list
    NSURL *current = [WallpaperManager sharedManager].currentVideoURL;
    if (current && [fm fileExistsAtPath:current.path]) {
        NSString *name = current.lastPathComponent.lowercaseString;
        if (![seenFileNames containsObject:name]) {
            [seenFileNames addObject:name];
            [results addObject:current];
        }
    }

    // Sort alphabetically by lastPathComponent
    [results sortUsingComparator:^NSComparisonResult(NSURL *url1, NSURL *url2) {
        return [url1.lastPathComponent localizedStandardCompare:url2.lastPathComponent];
    }];

    return results;
}

+ (NSURL *)importWallpaperAtURL:(NSURL *)sourceURL error:(NSError **)outError {
    if (!sourceURL || ![sourceURL isFileURL]) return nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *targetDir = [self userWallpapersDirectory];
    NSString *baseName = sourceURL.lastPathComponent.stringByDeletingPathExtension;
    NSString *extension = sourceURL.pathExtension;

    NSURL *destURL = [targetDir URLByAppendingPathComponent:sourceURL.lastPathComponent];
    NSUInteger counter = 1;
    while ([fm fileExistsAtPath:destURL.path]) {
        NSString *newName = [NSString stringWithFormat:@"%@_%lu.%@", baseName, (unsigned long)counter, extension];
        destURL = [targetDir URLByAppendingPathComponent:newName];
        counter++;
    }

    BOOL ok = [fm copyItemAtURL:sourceURL toURL:destURL error:outError];
    return ok ? destURL : nil;
}

+ (BOOL)deleteUserWallpaperAtURL:(NSURL *)wallpaperURL error:(NSError **)outError {
    if (!wallpaperURL) return NO;
    NSURL *userDir = [self userWallpapersDirectory];
    if (![wallpaperURL.path hasPrefix:userDir.path]) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"AuraWallpaper"
                                            code:-1
                                        userInfo:@{NSLocalizedDescriptionKey: @"Cannot delete bundled wallpaper."}];
        }
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm removeItemAtURL:wallpaperURL error:outError];
}

@end
