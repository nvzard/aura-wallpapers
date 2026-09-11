#import <Cocoa/Cocoa.h>
#import "WallpaperWindow.h"
#import "WallpaperViewController.h"

extern NSString * const AuraWallpaperDidChangeNotification;

@interface WallpaperManager : NSObject

@property (nonatomic, strong, readonly) NSURL *currentVideoURL;
@property (nonatomic, assign, readonly) BOOL isPlaying;
@property (nonatomic, assign, readonly) BOOL isMuted;
@property (nonatomic, assign, readonly) BOOL hidesDesktopIcons;
@property (nonatomic, assign, readonly) float volume;

+ (instancetype)sharedManager;

- (void)startWithDefaultOrSavedWallpaper;
- (void)setWallpaperVideoURL:(NSURL *)url;
- (void)playAll;
- (void)pauseAll;
- (void)togglePlayPause;
- (void)setMuted:(BOOL)muted;
- (void)setVolume:(float)volume;
- (void)setHideDesktopIcons:(BOOL)hide;
- (void)rebuildWindows;

+ (NSURL *)userWallpapersDirectory;
+ (NSArray<NSURL *> *)allAvailableWallpapers;
+ (NSURL *)importWallpaperAtURL:(NSURL *)sourceURL error:(NSError **)outError;
+ (BOOL)deleteUserWallpaperAtURL:(NSURL *)wallpaperURL error:(NSError **)outError;

@end
