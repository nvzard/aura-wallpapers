#import "AppDelegate.h"
#import "WallpaperManager.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <ServiceManagement/ServiceManagement.h>

@interface AppDelegate () {
    NSMenuItem *_playPauseItem;
    NSMenuItem *_muteItem;
    NSMenuItem *_hideIconsItem;
    NSMenuItem *_openAtLoginItem;
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

    _openAtLoginItem = [[NSMenuItem alloc] initWithTitle:@"Open at Login"
                                                  action:@selector(toggleOpenAtLoginAction:)
                                           keyEquivalent:@"l"];
    _openAtLoginItem.target = self;
    [menu addItem:_openAtLoginItem];

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
    _openAtLoginItem.state = [self isOpenAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
}

#pragma mark - Actions

- (BOOL)isOpenAtLoginEnabled {
    if (@available(macOS 13.0, *)) {
        return [SMAppService mainAppService].status == SMAppServiceStatusEnabled;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"OpenAtLogin"];
}

- (void)toggleOpenAtLoginAction:(id)sender {
    if (@available(macOS 13.0, *)) {
        SMAppService *service = [SMAppService mainAppService];
        NSError *error = nil;
        if (service.status == SMAppServiceStatusEnabled) {
            BOOL success = [service unregisterAndReturnError:&error];
            if (!success) {
                NSLog(@"[AuraWallpaper] Failed to unregister login item: %@", error);
            }
        } else {
            if (service.status == SMAppServiceStatusRequiresApproval) {
                [SMAppService openSystemSettingsLoginItems];
            } else {
                BOOL success = [service registerAndReturnError:&error];
                if (!success) {
                    NSLog(@"[AuraWallpaper] Failed to register login item: %@", error);
                    if (service.status == SMAppServiceStatusRequiresApproval) {
                        [SMAppService openSystemSettingsLoginItems];
                    }
                }
            }
        }
    } else {
        BOOL current = [[NSUserDefaults standardUserDefaults] boolForKey:@"OpenAtLogin"];
        [[NSUserDefaults standardUserDefaults] setBool:!current forKey:@"OpenAtLogin"];
    }

    _openAtLoginItem.state = [self isOpenAtLoginEnabled] ? NSControlStateValueOn : NSControlStateValueOff;
}

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
            NSURL *selectedURL = panel.URL;
            dispatch_async(dispatch_get_main_queue(), ^{
                [[WallpaperManager sharedManager] setWallpaperVideoURL:selectedURL];
            });
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
