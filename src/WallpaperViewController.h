#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import "ClickThroughPlayerView.h"

@interface WallpaperViewController : NSViewController

@property (nonatomic, strong, readonly) ClickThroughPlayerView *playerView;
@property (nonatomic, strong, readonly) AVQueuePlayer *player;
@property (nonatomic, strong, readonly) NSURL *currentURL;
@property (nonatomic, assign) BOOL isMuted;
@property (nonatomic, assign) float volume;

- (void)loadVideoURL:(NSURL *)url forScreen:(NSScreen *)screen;
- (void)play;
- (void)pause;
- (BOOL)isPlaying;
- (void)setMuted:(BOOL)muted;
- (void)setVolume:(float)volume;
- (void)cleanupPlayer;

+ (void)setDesktopSyncEnabled:(BOOL)enabled;
+ (BOOL)isDesktopSyncEnabled;

@end
