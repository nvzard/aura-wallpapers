#import <Cocoa/Cocoa.h>

@interface WallpaperWindow : NSWindow

@property (nonatomic, weak) NSScreen *targetScreen;
@property (nonatomic, assign) BOOL hidesDesktopIcons;

- (instancetype)initWithScreen:(NSScreen *)screen;
- (void)updateFrameForScreen;
- (void)setHidesDesktopIcons:(BOOL)hide;

@end
