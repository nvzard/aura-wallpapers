#import "WallpaperViewController.h"

@interface WallpaperViewController () {
    AVPlayerLooper *_playerLooper;
    uint64_t _syncGeneration;
}
@end

static BOOL sDesktopSyncEnabled = YES;

@implementation WallpaperViewController

+ (void)setDesktopSyncEnabled:(BOOL)enabled {
    sDesktopSyncEnabled = enabled;
}

+ (BOOL)isDesktopSyncEnabled {
    if (getenv("AURA_TEST_MODE") != NULL) {
        return NO;
    }
    return sDesktopSyncEnabled;
}

+ (NSURL *)previewsDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *appSupport = [fm URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = appSupport ? [appSupport URLByAppendingPathComponent:@"AuraWallpaper/Previews" isDirectory:YES] : nil;
    if (!dir) {
        dir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"AuraWallpaper/Previews"] isDirectory:YES];
    }
    if (![fm fileExistsAtPath:dir.path]) {
        [fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    return dir;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isMuted = YES;
        _volume = 0.0f;
        _syncGeneration = 0;
    }
    return self;
}

- (void)loadView {
    _playerView = [[ClickThroughPlayerView alloc] initWithFrame:NSZeroRect];
    self.view = _playerView;
}

- (void)dealloc {
    [self cleanupPlayer];
}

- (void)cleanupPlayer {
    _syncGeneration++;
    if (_playerLooper) {
        [_playerLooper disableLooping];
        _playerLooper = nil;
    }
    if (_player) {
        [_player pause];
        if (_playerView) {
            _playerView.player = nil;
        }
        [_player removeAllItems];
        _player = nil;
    }
}

- (void)loadVideoURL:(NSURL *)url forScreen:(NSScreen *)screen {
    if (!url) return;
    _currentURL = url;
    _syncGeneration++;
    uint64_t currentGen = _syncGeneration;

    AVQueuePlayer *oldPlayer = _player;
    AVPlayerLooper *oldLooper = _playerLooper;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];

    AVQueuePlayer *newPlayer = [[AVQueuePlayer alloc] init];
    newPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    // Hardware-accelerated seamless looping
    AVPlayerLooper *newLooper = [AVPlayerLooper playerLooperWithPlayer:newPlayer templateItem:item];

    _player = newPlayer;
    _playerLooper = newLooper;

    // Attach immediately to view so old video seamlessly hands off without a black gap
    self.playerView.player = newPlayer;
    self.playerView.videoGravity = AVLayerVideoGravityResizeAspectFill;
    newPlayer.muted = _isMuted;
    newPlayer.volume = _volume;

    [newPlayer play];

    // Clean up previous playback after transferring display to prevent black flicker
    if (oldLooper) {
        [oldLooper disableLooping];
    }
    if (oldPlayer) {
        [oldPlayer pause];
        [oldPlayer removeAllItems];
    }

    // Synchronize first frame with native macOS wallpaper safely and asynchronously
    if (screen) {
        [self syncFirstFrameToDesktop:asset forScreen:screen generation:currentGen];
    }
}

- (void)syncFirstFrameToDesktop:(AVAsset *)asset forScreen:(NSScreen *)screen {
    [self syncFirstFrameToDesktop:asset forScreen:screen generation:_syncGeneration];
}

- (void)syncFirstFrameToDesktop:(AVAsset *)asset forScreen:(NSScreen *)screen generation:(uint64_t)gen {
    if (![WallpaperViewController isDesktopSyncEnabled]) {
        return;
    }

    __weak typeof(self) weakSelf = self;
    static dispatch_queue_t sSyncQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sSyncQueue = dispatch_queue_create("com.nitanshu.aurawallpaper.desktopsync", DISPATCH_QUEUE_SERIAL);
    });

    dispatch_async(sSyncQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_syncGeneration != gen) {
            return;
        }

        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.requestedTimeToleranceBefore = kCMTimePositiveInfinity;
        generator.requestedTimeToleranceAfter = kCMTimePositiveInfinity;
        CMTime requestedTime = CMTimeMake(1, 60);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSError *extractErr = nil;
        CGImageRef imageRef = [generator copyCGImageAtTime:requestedTime actualTime:NULL error:&extractErr];
#pragma clang diagnostic pop

        if (!imageRef && extractErr) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            imageRef = [generator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:NULL];
#pragma clang diagnostic pop
        }

        if (!imageRef) return;

        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
        CGImageRelease(imageRef);
        if (!rep) return;

        // Efficient high-quality JPEG avoids 10MB PNG allocation and freezes
        NSDictionary *props = @{NSImageCompressionFactor: @0.85};
        NSData *imageData = [rep representationUsingType:NSBitmapImageFileTypeJPEG properties:props];
        if (!imageData || imageData.length == 0) return;

        NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
        unsigned long screenID = screenNumber ? [screenNumber unsignedLongValue] : (unsigned long)screen.hash;

        NSURL *previewsDir = [WallpaperViewController previewsDirectory];
        NSString *fileName = [NSString stringWithFormat:@"preview_%lx_%lx.jpg",
                              (unsigned long)[strongSelf.currentURL.path hash],
                              screenID];
        NSURL *fileURL = [previewsDir URLByAppendingPathComponent:fileName];

        // Safe atomic write
        BOOL written = [imageData writeToURL:fileURL atomically:YES];
        if (!written) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) currentSelf = weakSelf;
            if (!currentSelf || currentSelf->_syncGeneration != gen) {
                return;
            }

            NSDictionary *options = @{
                NSWorkspaceDesktopImageScalingKey: @(NSImageScaleProportionallyUpOrDown),
                NSWorkspaceDesktopImageAllowClippingKey: @YES
            };
            [[NSWorkspace sharedWorkspace] setDesktopImageURL:fileURL forScreen:screen options:options error:NULL];
        });
    });
}

- (void)play {
    if (_player) {
        [_player play];
    }
}

- (void)pause {
    if (_player) {
        [_player pause];
    }
}

- (BOOL)isPlaying {
    return _player && _player.rate > 0.0f;
}

- (void)setMuted:(BOOL)muted {
    _isMuted = muted;
    if (_player) {
        _player.muted = muted;
    }
}

- (void)setVolume:(float)volume {
    _volume = volume;
    if (_player) {
        _player.volume = volume;
    }
}

@end
