#import "WallpaperViewController.h"

@interface WallpaperViewController () {
    AVPlayerLooper *_playerLooper;
    id _endObserver;
}
@end

@implementation WallpaperViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        _isMuted = YES;
        _volume = 0.0f;
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
    if (_endObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_endObserver];
        _endObserver = nil;
    }
    if (_player) {
        [_player pause];
        [_player removeAllItems];
        _player = nil;
    }
    _playerLooper = nil;
}

- (void)loadVideoURL:(NSURL *)url forScreen:(NSScreen *)screen {
    if (!url) return;
    _currentURL = url;
    [self cleanupPlayer];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];

    _player = [AVQueuePlayer queuePlayerWithItems:@[item]];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;

    // Hardware-accelerated seamless looping
    _playerLooper = [AVPlayerLooper playerLooperWithPlayer:_player templateItem:item];

    // Notification fallback
    __weak typeof(self) weakSelf = self;
    _endObserver = [[NSNotificationCenter defaultCenter]
        addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * _Nonnull note) {
                    [weakSelf.player seekToTime:kCMTimeZero];
                }];

    self.playerView.player = _player;
    self.playerView.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _player.muted = _isMuted;
    _player.volume = _volume;

    [_player play];

    // Synchronize first frame with native macOS wallpaper to avoid boot/switch flicker
    if (screen) {
        [self syncFirstFrameToDesktop:asset forScreen:screen];
    }
}

- (void)syncFirstFrameToDesktop:(AVAsset *)asset forScreen:(NSScreen *)screen {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        CMTime requestedTime = CMTimeMake(1, 60);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CGImageRef imageRef = [generator copyCGImageAtTime:requestedTime actualTime:NULL error:NULL];
#pragma clang diagnostic pop
        if (!imageRef) return;

        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
        NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        CGImageRelease(imageRef);

        if (!pngData) return;

        NSString *cacheDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"AuraWallpaper"];
        [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *imagePath = [cacheDir stringByAppendingPathComponent:[NSString stringWithFormat:@"preview_%lu.png", (unsigned long)screen.hash]];
        [pngData writeToFile:imagePath atomically:YES];

        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
            [[NSWorkspace sharedWorkspace] setDesktopImageURL:imageURL forScreen:screen options:@{} error:NULL];
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
