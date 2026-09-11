#import "test_framework.h"
#import "WallpaperViewController.h"

TEST_CASE(test_wallpaper_view_controller_initial_state) {
    WallpaperViewController *vc = [[WallpaperViewController alloc] init];
    ASSERT_NOT_NULL(vc);
    ASSERT_TRUE(vc.isMuted);
    ASSERT_FLOAT_EQUAL(vc.volume, 0.0f, 0.001);
    ASSERT_NULL(vc.player);
    ASSERT_NULL(vc.currentURL);

    // Trigger view loading
    NSView *v = vc.view;
    ASSERT_NOT_NULL(v);
    ASSERT_TRUE([v isKindOfClass:[ClickThroughPlayerView class]]);
    ASSERT_TRUE(vc.playerView == v);
}

TEST_CASE(test_desktop_sync_safety_switch) {
    // 1. With AURA_TEST_MODE set, it MUST always remain disabled regardless of flag
    setenv("AURA_TEST_MODE", "1", 1);
    [WallpaperViewController setDesktopSyncEnabled:YES];
    ASSERT_FALSE([WallpaperViewController isDesktopSyncEnabled]);

    [WallpaperViewController setDesktopSyncEnabled:NO];
    ASSERT_FALSE([WallpaperViewController isDesktopSyncEnabled]);

    // 2. Without AURA_TEST_MODE, it obeys the runtime property
    unsetenv("AURA_TEST_MODE");
    [WallpaperViewController setDesktopSyncEnabled:YES];
    ASSERT_TRUE([WallpaperViewController isDesktopSyncEnabled]);

    [WallpaperViewController setDesktopSyncEnabled:NO];
    ASSERT_FALSE([WallpaperViewController isDesktopSyncEnabled]);

    // 3. Restore test mode environment for subsequent tests
    setenv("AURA_TEST_MODE", "1", 1);
    [WallpaperViewController setDesktopSyncEnabled:NO];
    ASSERT_FALSE([WallpaperViewController isDesktopSyncEnabled]);
}

TEST_CASE(test_wallpaper_loading_and_teardown_lifecycle) {
    [WallpaperViewController setDesktopSyncEnabled:NO];

    WallpaperViewController *vc = [[WallpaperViewController alloc] init];
    (void)vc.view; // ensure view is loaded

    NSURL *videoURL = [NSURL fileURLWithPath:@"assets/default_wallpaper.mp4"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:videoURL.path]) {
        // Fallback check
        videoURL = [NSURL fileURLWithPath:@"assets/ghibli_landscape_4k.mp4"];
    }
    ASSERT_TRUE([[NSFileManager defaultManager] fileExistsAtPath:videoURL.path]);

    // Load video without a screen target to avoid macOS desktop wallpaper alteration
    [vc loadVideoURL:videoURL forScreen:nil];

    ASSERT_NOT_NULL(vc.player);
    ASSERT_NOT_NULL(vc.currentURL);
    ASSERT_STRING_EQUAL(vc.currentURL.path, videoURL.path);
    ASSERT_TRUE(vc.playerView.player == vc.player);
    ASSERT_TRUE(vc.player.isMuted);

    // Audio adjustments
    [vc setMuted:NO];
    ASSERT_FALSE(vc.isMuted);
    ASSERT_FALSE(vc.player.isMuted);

    [vc setVolume:0.75f];
    ASSERT_FLOAT_EQUAL(vc.volume, 0.75f, 0.01);
    ASSERT_FLOAT_EQUAL(vc.player.volume, 0.75f, 0.01);

    // Teardown
    [vc cleanupPlayer];
    ASSERT_NULL(vc.player);
    ASSERT_NULL(vc.playerView.player);

    // Multiple teardowns should be cleanly idempotent
    [vc cleanupPlayer];
}

void run_wallpaper_view_controller_tests(void) {
    TEST_SUITE_BEGIN("WallpaperViewController Unit Tests");
    RUN_TEST(test_wallpaper_view_controller_initial_state);
    RUN_TEST(test_desktop_sync_safety_switch);
    RUN_TEST(test_wallpaper_loading_and_teardown_lifecycle);
    TEST_SUITE_END();
}
