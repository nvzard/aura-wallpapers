#import "test_framework.h"
#import "WallpaperWindow.h"
#import "ClickThroughPlayerView.h"

TEST_CASE(test_wallpaper_window_initialization) {
    NSScreen *screen = [NSScreen mainScreen];
    ASSERT_NOT_NULL(screen);

    WallpaperWindow *window = [[WallpaperWindow alloc] initWithScreen:screen];
    ASSERT_NOT_NULL(window);

    // Transparency & presentation
    ASSERT_FALSE(window.isOpaque);
    ASSERT_FALSE(window.hasShadow);
    ASSERT_EQUAL(window.animationBehavior, NSWindowAnimationBehaviorNone);
    ASSERT_TRUE(window.ignoresMouseEvents);
    ASSERT_FALSE(window.canBecomeKeyWindow);
    ASSERT_FALSE(window.canBecomeMainWindow);

    // Collection behavior for desktop integration
    NSWindowCollectionBehavior cb = window.collectionBehavior;
    ASSERT_TRUE((cb & NSWindowCollectionBehaviorCanJoinAllSpaces) != 0);
    ASSERT_TRUE((cb & NSWindowCollectionBehaviorStationary) != 0);
    ASSERT_TRUE((cb & NSWindowCollectionBehaviorIgnoresCycle) != 0);

    // Initial window level (behind Finder icons)
    ASSERT_EQUAL(window.level, CGWindowLevelForKey(kCGDesktopWindowLevelKey));
    ASSERT_FALSE(window.hidesDesktopIcons);

    [window close];
}

TEST_CASE(test_wallpaper_window_level_switching) {
    NSScreen *screen = [NSScreen mainScreen];
    ASSERT_NOT_NULL(screen);

    WallpaperWindow *window = [[WallpaperWindow alloc] initWithScreen:screen];
    ASSERT_NOT_NULL(window);

    // Default: Behind desktop icons
    ASSERT_EQUAL(window.level, CGWindowLevelForKey(kCGDesktopWindowLevelKey));

    // Hide desktop icons mode: elevate above desktop overlay
    [window setHidesDesktopIcons:YES];
    ASSERT_TRUE(window.hidesDesktopIcons);
    ASSERT_EQUAL(window.level, (NSInteger)(CGWindowLevelForKey(kCGOverlayWindowLevelKey) + 1));

    // Return to behind desktop icons
    [window setHidesDesktopIcons:NO];
    ASSERT_FALSE(window.hidesDesktopIcons);
    ASSERT_EQUAL(window.level, CGWindowLevelForKey(kCGDesktopWindowLevelKey));

    [window close];
}

TEST_CASE(test_click_through_player_view) {
    ClickThroughPlayerView *view = [[ClickThroughPlayerView alloc] initWithFrame:NSMakeRect(0, 0, 500, 500)];
    ASSERT_NOT_NULL(view);

    // Hit-testing MUST return nil at any coordinates so events pass straight to Finder
    ASSERT_NULL([view hitTest:NSMakePoint(0, 0)]);
    ASSERT_NULL([view hitTest:NSMakePoint(250, 250)]);
    ASSERT_NULL([view hitTest:NSMakePoint(499, 499)]);
    ASSERT_NULL([view hitTest:NSMakePoint(-10, -10)]);
}

void run_wallpaper_window_tests(void) {
    TEST_SUITE_BEGIN("WallpaperWindow & ClickThroughPlayerView Unit Tests");
    RUN_TEST(test_wallpaper_window_initialization);
    RUN_TEST(test_wallpaper_window_level_switching);
    RUN_TEST(test_click_through_player_view);
    TEST_SUITE_END();
}
