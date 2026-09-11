#import "AppDelegate.h"
#import "WallpaperManager.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface AppDelegate () {
    NSMenuItem *_playPauseItem;
    NSMenuItem *_muteItem;
    NSMenuItem *_hideIconsItem;
    NSMenuItem *_currentFileItem;
}
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Setup status item in system menu bar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        NSImage *icon = [NSImage imageWithSystemSymbolName:@"sparkles.tv" accessibilityDescription:@"Aura Live Wallpaper"];
        if (!icon) {
            icon = [NSImage imageWithSystemSymbolName:@"display" accessibilityDescription:@"Aura Live Wallpaper"];
        }
        button.image = icon;
    }

    [self setupMenu];

    // Launch wallpaper playback
    [[WallpaperManager sharedManager] startWithDefaultOrSavedWallpaper];
}

- (void)setupMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Aura Wallpaper"];
    menu.delegate = self;

    _currentFileItem = [[NSMenuItem alloc] initWithTitle:@"Aura Live Wallpaper" action:nil keyEquivalent:@""];
    [_currentFileItem setEnabled:NO];
    [menu addItem:_currentFileItem];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *chooseItem = [[NSMenuItem alloc] initWithTitle:@"Choose Video Wallpaper..."
                                                        action:@selector(chooseVideoAction:)
                                                 keyEquivalent:@"o"];
    chooseItem.target = self;
    [menu addItem:chooseItem];

    _playPauseItem = [[NSMenuItem alloc] initWithTitle:@"Pause Wallpaper"
                                                action:@selector(togglePlayPauseAction:)
                                         keyEquivalent:@"p"];
    _playPauseItem.target = self;
    [menu addItem:_playPauseItem];

    _muteItem = [[NSMenuItem alloc] initWithTitle:@"Unmute Audio"
                                           action:@selector(toggleMuteAction:)
                                    keyEquivalent:@"m"];
    _muteItem.target = self;
    [menu addItem:_muteItem];

    [menu addItem:[NSMenuItem separatorItem]];

    _hideIconsItem = [[NSMenuItem alloc] initWithTitle:@"Hide Desktop Icons"
                                                action:@selector(toggleHideIconsAction:)
                                         keyEquivalent:@"h"];
    _hideIconsItem.target = self;
    [menu addItem:_hideIconsItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit Aura Wallpaper"
                                                      action:@selector(quitAction:)
                                               keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    self.statusItem.menu = menu;
}

- (void)menuWillOpen:(NSMenu *)menu {
    WallpaperManager *mgr = [WallpaperManager sharedManager];

    if (mgr.currentVideoURL) {
        NSString *fileName = mgr.currentVideoURL.lastPathComponent;
        _currentFileItem.title = [NSString stringWithFormat:@"Playing: %@", fileName];
    } else {
        _currentFileItem.title = @"No Wallpaper Active";
    }

    _playPauseItem.title = mgr.isPlaying ? @"Pause Wallpaper" : @"Resume Wallpaper";
    _muteItem.title = mgr.isMuted ? @"Unmute Audio" : @"Mute Audio";
    _hideIconsItem.state = mgr.hidesDesktopIcons ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - Actions

- (void)chooseVideoAction:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowedContentTypes = @[
        [UTType typeWithFilenameExtension:@"mp4"],
        [UTType typeWithFilenameExtension:@"mov"],
        [UTType typeWithFilenameExtension:@"m4v"],
        [UTType typeWithFilenameExtension:@"webm"]
    ];
    panel.message = @"Select a high-definition looping video for your desktop wallpaper:";

    // Activate app so the modal panel is frontmost
    [NSApp activateIgnoringOtherApps:YES];

    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL) {
            [[WallpaperManager sharedManager] setWallpaperVideoURL:panel.URL];
        }
    }];
}

- (void)togglePlayPauseAction:(id)sender {
    [[WallpaperManager sharedManager] togglePlayPause];
}

- (void)toggleMuteAction:(id)sender {
    WallpaperManager *mgr = [WallpaperManager sharedManager];
    [mgr setMuted:!mgr.isMuted];
}

- (void)toggleHideIconsAction:(id)sender {
    WallpaperManager *mgr = [WallpaperManager sharedManager];
    [mgr setHideDesktopIcons:!mgr.hidesDesktopIcons];
}

- (void)quitAction:(id)sender {
    [NSApp terminate:nil];
}

@end
