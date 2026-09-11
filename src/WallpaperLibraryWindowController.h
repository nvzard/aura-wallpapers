#import <Cocoa/Cocoa.h>

@interface WallpaperLibraryWindowController : NSWindowController

+ (instancetype)sharedController;

- (void)showLibrary;
- (void)reloadWallpapers;
+ (NSString *)prettifiedTitleForFilename:(NSString *)fileName;

@end
