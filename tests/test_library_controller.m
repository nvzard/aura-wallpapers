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

void run_library_controller_tests(void) {
    TEST_SUITE_BEGIN("WallpaperLibraryWindowController Unit Tests");
    RUN_TEST(test_prettify_wallpaper_titles);
    RUN_TEST(test_library_window_controller_setup);
    TEST_SUITE_END();
}
