#import "test_framework.h"
#import "WallpaperManager.h"
#import "WallpaperViewController.h"

TEST_CASE(test_wallpaper_manager_singleton) {
    WallpaperManager *m1 = [WallpaperManager sharedManager];
    WallpaperManager *m2 = [WallpaperManager sharedManager];
    ASSERT_NOT_NULL(m1);
    ASSERT_NOT_NULL(m2);
    ASSERT_TRUE(m1 == m2);
}

TEST_CASE(test_wallpaper_manager_state_and_defaults) {
    WallpaperManager *mgr = [WallpaperManager sharedManager];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    // Backup current defaults
    id savedMuted = [defs objectForKey:@"AuraWallpaperMuted"];
    id savedVolume = [defs objectForKey:@"AuraWallpaperVolume"];
    id savedHideIcons = [defs objectForKey:@"AuraWallpaperHideIcons"];

    // Test mute toggle
    [mgr setMuted:YES];
    ASSERT_TRUE(mgr.isMuted);
    ASSERT_TRUE([defs boolForKey:@"AuraWallpaperMuted"]);

    [mgr setMuted:NO];
    ASSERT_FALSE(mgr.isMuted);
    ASSERT_FALSE([defs boolForKey:@"AuraWallpaperMuted"]);

    // Test volume
    [mgr setVolume:0.65f];
    ASSERT_FLOAT_EQUAL(mgr.volume, 0.65f, 0.001);
    ASSERT_FLOAT_EQUAL([defs floatForKey:@"AuraWallpaperVolume"], 0.65f, 0.001);

    // Test hide desktop icons toggle
    [mgr setHideDesktopIcons:YES];
    ASSERT_TRUE(mgr.hidesDesktopIcons);
    ASSERT_TRUE([defs boolForKey:@"AuraWallpaperHideIcons"]);

    [mgr setHideDesktopIcons:NO];
    ASSERT_FALSE(mgr.hidesDesktopIcons);
    ASSERT_FALSE([defs boolForKey:@"AuraWallpaperHideIcons"]);

    // Test play / pause controls
    [mgr pauseAll];
    ASSERT_FALSE(mgr.isPlaying);

    [mgr playAll];
    ASSERT_TRUE(mgr.isPlaying);

    [mgr togglePlayPause];
    ASSERT_FALSE(mgr.isPlaying);

    [mgr togglePlayPause];
    ASSERT_TRUE(mgr.isPlaying);

    // Restore original settings
    if (savedMuted) [defs setObject:savedMuted forKey:@"AuraWallpaperMuted"];
    else [defs removeObjectForKey:@"AuraWallpaperMuted"];

    if (savedVolume) [defs setObject:savedVolume forKey:@"AuraWallpaperVolume"];
    else [defs removeObjectForKey:@"AuraWallpaperVolume"];

    if (savedHideIcons) [defs setObject:savedHideIcons forKey:@"AuraWallpaperHideIcons"];
    else [defs removeObjectForKey:@"AuraWallpaperHideIcons"];
    [defs synchronize];
}

TEST_CASE(test_user_wallpapers_directory) {
    NSURL *dir = [WallpaperManager userWallpapersDirectory];
    ASSERT_NOT_NULL(dir);
    ASSERT_TRUE([dir.path containsString:@"AuraWallpaper/Wallpapers"]);
    
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:dir.path isDirectory:&isDir];
    ASSERT_TRUE(exists);
    ASSERT_TRUE(isDir);
}

TEST_CASE(test_all_available_wallpapers_discovery) {
    NSArray<NSURL *> *wallpapers = [WallpaperManager allAvailableWallpapers];
    ASSERT_NOT_NULL(wallpapers);
    ASSERT_TRUE(wallpapers.count > 0);

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *validExts = @[@"mp4", @"mov", @"m4v", @"webm"];
    
    for (NSUInteger i = 0; i < wallpapers.count; i++) {
        NSURL *url = wallpapers[i];
        ASSERT_TRUE([fm fileExistsAtPath:url.path]);
        NSString *ext = url.pathExtension.lowercaseString;
        ASSERT_TRUE([validExts containsObject:ext]);

        // Check alphabetical sorting
        if (i > 0) {
            NSURL *prev = wallpapers[i - 1];
            NSComparisonResult order = [prev.lastPathComponent localizedStandardCompare:url.lastPathComponent];
            ASSERT_TRUE(order == NSOrderedAscending || order == NSOrderedSame);
        }
    }
}

TEST_CASE(test_import_and_delete_user_wallpaper) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tempDir = NSTemporaryDirectory();
    NSString *dummyFileName = [NSString stringWithFormat:@"aura_test_temp_%u.mp4", arc4random_uniform(100000)];
    NSString *sourcePath = [tempDir stringByAppendingPathComponent:dummyFileName];
    
    // Create a dummy video file
    NSData *dummyData = [@"DUMMY_MP4_CONTENT_FOR_UNIT_TEST" dataUsingEncoding:NSUTF8StringEncoding];
    [dummyData writeToFile:sourcePath atomically:YES];
    ASSERT_TRUE([fm fileExistsAtPath:sourcePath]);

    NSURL *sourceURL = [NSURL fileURLWithPath:sourcePath];
    NSError *error = nil;

    // 1. First import
    NSURL *destURL1 = [WallpaperManager importWallpaperAtURL:sourceURL error:&error];
    ASSERT_NOT_NULL(destURL1);
    ASSERT_NULL(error);
    ASSERT_TRUE([fm fileExistsAtPath:destURL1.path]);
    ASSERT_STRING_EQUAL(destURL1.lastPathComponent, dummyFileName);

    // 2. Second import (duplicate name handling -> should append _1.mp4)
    NSURL *destURL2 = [WallpaperManager importWallpaperAtURL:sourceURL error:&error];
    ASSERT_NOT_NULL(destURL2);
    ASSERT_NULL(error);
    ASSERT_TRUE([fm fileExistsAtPath:destURL2.path]);
    
    NSString *base = dummyFileName.stringByDeletingPathExtension;
    NSString *ext = dummyFileName.pathExtension;
    NSString *expectedDupName = [NSString stringWithFormat:@"%@_1.%@", base, ext];
    ASSERT_STRING_EQUAL(destURL2.lastPathComponent, expectedDupName);

    // 3. Security test: trying to delete a file outside user directory MUST fail
    NSURL *outsideURL = [NSURL fileURLWithPath:@"/System/Library/CoreServices/Finder.app"];
    BOOL delOutside = [WallpaperManager deleteUserWallpaperAtURL:outsideURL error:&error];
    ASSERT_FALSE(delOutside);
    ASSERT_NOT_NULL(error);

    // 4. Delete the imported test files
    error = nil;
    BOOL del1 = [WallpaperManager deleteUserWallpaperAtURL:destURL1 error:&error];
    ASSERT_TRUE(del1);
    ASSERT_NULL(error);
    ASSERT_FALSE([fm fileExistsAtPath:destURL1.path]);

    BOOL del2 = [WallpaperManager deleteUserWallpaperAtURL:destURL2 error:&error];
    ASSERT_TRUE(del2);
    ASSERT_NULL(error);
    ASSERT_FALSE([fm fileExistsAtPath:destURL2.path]);

    // Clean up temporary source file
    [fm removeItemAtPath:sourcePath error:NULL];
}

TEST_CASE(test_wallpaper_change_notification) {
    WallpaperManager *mgr = [WallpaperManager sharedManager];
    [WallpaperViewController setDesktopSyncEnabled:NO];

    NSArray<NSURL *> *available = [WallpaperManager allAvailableWallpapers];
    ASSERT_TRUE(available.count > 0);
    NSURL *targetURL = available.firstObject;

    __block BOOL receivedNotification = NO;
    __block NSURL *notifiedURL = nil;

    id observer = [[NSNotificationCenter defaultCenter]
        addObserverForName:AuraWallpaperDidChangeNotification
                    object:mgr
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * _Nonnull note) {
                    receivedNotification = YES;
                    notifiedURL = note.userInfo[@"url"];
                }];

    [mgr setWallpaperVideoURL:targetURL];

    ASSERT_TRUE(receivedNotification);
    ASSERT_NOT_NULL(notifiedURL);
    ASSERT_STRING_EQUAL(notifiedURL.path, targetURL.path);

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

void run_wallpaper_manager_tests(void) {
    TEST_SUITE_BEGIN("WallpaperManager Unit Tests");
    RUN_TEST(test_wallpaper_manager_singleton);
    RUN_TEST(test_wallpaper_manager_state_and_defaults);
    RUN_TEST(test_user_wallpapers_directory);
    RUN_TEST(test_all_available_wallpapers_discovery);
    RUN_TEST(test_import_and_delete_user_wallpaper);
    RUN_TEST(test_wallpaper_change_notification);
    TEST_SUITE_END();
}
