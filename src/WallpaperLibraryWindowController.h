#import <Cocoa/Cocoa.h>

@interface WallpaperActiveBadgeView : NSView

@property (nonatomic, readonly) NSImageView *iconView;
@property (nonatomic, readonly) NSTextField *label;

@end

@interface WallpaperCardView : NSView

@property (nonatomic, strong) NSURL *wallpaperURL;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isUserWallpaper;
@property (nonatomic, readonly) WallpaperActiveBadgeView *activeBadgeView;
@property (nonatomic, copy) void (^onSelect)(NSURL *url);
@property (nonatomic, copy) void (^onDelete)(NSURL *url);

- (instancetype)initWithWallpaperURL:(NSURL *)url
                            isActive:(BOOL)isActive
                     isUserWallpaper:(BOOL)isUserWallpaper;
- (void)updateActiveState:(BOOL)isActive;

@end

@interface WallpaperLibraryWindowController : NSWindowController

+ (instancetype)sharedController;

- (void)showLibrary;
- (void)reloadWallpapers;
+ (NSString *)prettifiedTitleForFilename:(NSString *)fileName;

@end
