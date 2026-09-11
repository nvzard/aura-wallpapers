#import "test_framework.h"
#import "WallpaperLibraryWindowController.h"

TEST_CASE(test_prettify_wallpaper_titles) {
    NSString *t1 = [WallpaperLibraryWindowController prettifiedTitleForFilename:@"ghibli_landscape_4k.mp4"];
    ASSERT_STRING_EQUAL(t1, @"Ghibli Landscape 4K");

    NSString *t2 = [WallpaperLibraryWindowController prettifiedTitleForFilename:@"cosmic-nebula-hd.mov"];
    ASSERT_STRING_EQUAL(t2, @"Cosmic Nebula Hd");

    NSString *t3 = [WallpaperLibraryWindowController prettifiedTitleForFilename:@"cyberpunk_rain_city.webm"];
    ASSERT_STRING_EQUAL(t3, @"Cyberpunk Rain City");

    NSString *t4 = [WallpaperLibraryWindowController prettifiedTitleForFilename:@"simple_wallpaper.m4v"];
    ASSERT_STRING_EQUAL(t4, @"Simple Wallpaper");

    NSString *t5 = [WallpaperLibraryWindowController prettifiedTitleForFilename:@"singleword.mp4"];
    ASSERT_STRING_EQUAL(t5, @"Singleword");
}

TEST_CASE(test_library_window_controller_setup) {
    WallpaperLibraryWindowController *ctrl = [WallpaperLibraryWindowController sharedController];
    ASSERT_NOT_NULL(ctrl);
    ASSERT_NOT_NULL(ctrl.window);

    // Verify window config
    ASSERT_STRING_EQUAL(ctrl.window.title, @"Wallpaper Library");
    ASSERT_TRUE(ctrl.window.titlebarAppearsTransparent);
    ASSERT_FALSE(ctrl.window.isReleasedWhenClosed);
}

TEST_CASE(test_active_badge_view_styling_and_alignment) {
    WallpaperActiveBadgeView *badge = [[WallpaperActiveBadgeView alloc] initWithFrame:NSZeroRect];
    ASSERT_NOT_NULL(badge);
    ASSERT_TRUE(badge.wantsLayer);
    ASSERT_TRUE(badge.isFlipped);

    // Label verification
    ASSERT_NOT_NULL(badge.label);
    ASSERT_STRING_EQUAL(badge.label.stringValue, @"Active");
    ASSERT_NOT_NULL(badge.label.font);
    ASSERT_NOT_NULL(badge.label.textColor);

    // Icon verification
    ASSERT_NOT_NULL(badge.iconView);
    ASSERT_NOT_NULL(badge.iconView.image);

    // Dimensions and padding
    NSSize fit = [badge fittingSize];
    ASSERT_TRUE(fit.height == 22.0);
    ASSERT_TRUE(fit.width >= 60.0 && fit.width <= 80.0);

    // Layout
    badge.frame = NSMakeRect(0, 0, fit.width, fit.height);
    [badge layout];

    // Corner radius should be capsule (half of height)
    ASSERT_TRUE(badge.layer.cornerRadius == 11.0);

    // Checkmark icon must be on the left, label on the right
    ASSERT_TRUE(badge.iconView.frame.origin.x >= 7.0);
    ASSERT_TRUE(badge.label.frame.origin.x > NSMaxX(badge.iconView.frame));
    ASSERT_TRUE(NSMaxX(badge.label.frame) <= fit.width);

    // Both icon and label must be vertically centered inside the 22pt height
    ASSERT_TRUE(badge.iconView.frame.origin.y >= 2.0 && NSMaxY(badge.iconView.frame) <= 20.0);
    ASSERT_TRUE(badge.label.frame.origin.y >= 2.0 && NSMaxY(badge.label.frame) <= 20.0);
}

TEST_CASE(test_card_view_active_badge_behavior) {
    NSURL *testURL = [NSURL fileURLWithPath:@"/tmp/auratest_active_badge.mp4"];
    WallpaperCardView *activeCard = [[WallpaperCardView alloc] initWithWallpaperURL:testURL
                                                                           isActive:YES
                                                                    isUserWallpaper:NO];
    ASSERT_NOT_NULL(activeCard);
    ASSERT_NOT_NULL(activeCard.activeBadgeView);
    ASSERT_FALSE(activeCard.activeBadgeView.isHidden);

    // Toggle active state to NO
    [activeCard updateActiveState:NO];
    ASSERT_TRUE(activeCard.activeBadgeView.isHidden);

    // Toggle active state back to YES
    [activeCard updateActiveState:YES];
    ASSERT_FALSE(activeCard.activeBadgeView.isHidden);

    // Layout card and verify badge positioning
    activeCard.frame = NSMakeRect(0, 0, 240, 180);
    [activeCard layout];

    NSRect badgeFrame = activeCard.activeBadgeView.frame;
    ASSERT_TRUE(badgeFrame.size.height == 22.0);
    ASSERT_TRUE(badgeFrame.origin.x > 100.0); // Placed at top-right
    ASSERT_TRUE(NSMaxX(badgeFrame) <= activeCard.bounds.size.width);
}

void run_library_controller_tests(void) {
    TEST_SUITE_BEGIN("WallpaperLibraryWindowController Unit Tests");
    RUN_TEST(test_prettify_wallpaper_titles);
    RUN_TEST(test_library_window_controller_setup);
    RUN_TEST(test_active_badge_view_styling_and_alignment);
    RUN_TEST(test_card_view_active_badge_behavior);
    TEST_SUITE_END();
}

