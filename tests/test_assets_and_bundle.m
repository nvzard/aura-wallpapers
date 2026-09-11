#import "test_framework.h"
#import <AVFoundation/AVFoundation.h>

TEST_CASE(test_info_plist_configuration) {
    NSString *plistPath = @"assets/Info.plist";
    NSFileManager *fm = [NSFileManager defaultManager];
    ASSERT_TRUE([fm fileExistsAtPath:plistPath]);

    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    ASSERT_NOT_NULL(dict);

    // LSUIElement MUST be YES to run purely as menu bar agent without Dock icon
    id lsUIElement = dict[@"LSUIElement"];
    ASSERT_NOT_NULL(lsUIElement);
    ASSERT_TRUE([lsUIElement boolValue]);

    // Basic bundle identifiers
    ASSERT_NOT_NULL(dict[@"CFBundleIdentifier"]);
    ASSERT_NOT_NULL(dict[@"CFBundleVersion"]);
    ASSERT_STRING_EQUAL(dict[@"CFBundlePackageType"], @"APPL");
}

TEST_CASE(test_bundled_video_assets_integrity) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *assetsPath = @"assets";
    NSArray<NSString *> *files = [fm contentsOfDirectoryAtPath:assetsPath error:NULL];
    ASSERT_NOT_NULL(files);

    NSUInteger videoCount = 0;
    NSArray<NSString *> *videoExts = @[@"mp4", @"mov", @"m4v", @"webm"];

    for (NSString *file in files) {
        NSString *ext = file.pathExtension.lowercaseString;
        if (![videoExts containsObject:ext]) {
            continue;
        }

        videoCount++;
        NSString *fullPath = [assetsPath stringByAppendingPathComponent:file];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:NULL];
        unsigned long long fileSize = [attrs fileSize];
        
        // Videos should have reasonable size (> 100KB)
        ASSERT_TRUE(fileSize > 100 * 1024);

        // AVAsset verification
        NSURL *fileURL = [NSURL fileURLWithPath:fullPath];
        AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
        ASSERT_NOT_NULL(asset);
        ASSERT_TRUE(asset.isPlayable);

        Float64 duration = CMTimeGetSeconds(asset.duration);
        ASSERT_TRUE(duration > 0.1);

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray<AVAssetTrack *> *tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
        ASSERT_TRUE(tracks.count >= 1);

        CGSize size = tracks.firstObject.naturalSize;
        ASSERT_TRUE(size.width > 0);
        ASSERT_TRUE(size.height > 0);
    }

    // Must have at least default_wallpaper.mp4
    ASSERT_TRUE(videoCount >= 1);
}

void run_assets_and_bundle_tests(void) {
    TEST_SUITE_BEGIN("Assets & Bundle Configuration Tests");
    RUN_TEST(test_info_plist_configuration);
    RUN_TEST(test_bundled_video_assets_integrity);
    TEST_SUITE_END();
}
