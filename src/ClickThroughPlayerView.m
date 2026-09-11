#import "ClickThroughPlayerView.h"

@implementation ClickThroughPlayerView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.controlsStyle = AVPlayerViewControlsStyleNone;
        self.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.updatesNowPlayingInfoCenter = NO;
    }
    return self;
}

// Pass all mouse events directly through to Finder / desktop icons
- (NSView *)hitTest:(NSPoint)point {
    return nil;
}

@end
