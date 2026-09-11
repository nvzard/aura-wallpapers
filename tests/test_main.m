#import <Cocoa/Cocoa.h>
#import "test_framework.h"
#import "WallpaperViewController.h"

TestContext g_test_ctx = {0, 0, 0, 0};

// Forward declarations of test suites
void run_wallpaper_manager_tests(void);
void run_wallpaper_window_tests(void);
void run_wallpaper_view_controller_tests(void);
void run_library_controller_tests(void);
void run_assets_and_bundle_tests(void);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Enforce test mode: disables any real desktop wallpaper manipulation
        setenv("AURA_TEST_MODE", "1", 1);
        [WallpaperViewController setDesktopSyncEnabled:NO];

        // Initialize NSApplication runtime for Cocoa UI / Window tests
        [NSApplication sharedApplication];
        test_framework_init();

        printf(ANSI_COLOR_BOLD "==================================================\n");
        printf("🧪 AuraWallpaper Automated Test Suite\n");
        printf("==================================================" ANSI_COLOR_RESET "\n");

        run_wallpaper_manager_tests();
        run_wallpaper_window_tests();
        run_wallpaper_view_controller_tests();
        run_library_controller_tests();
        run_assets_and_bundle_tests();

        return test_framework_summary();
    }
}
