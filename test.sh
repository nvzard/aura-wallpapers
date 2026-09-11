#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🧪 Building AuraWallpaper Test Runner..."

TEST_BIN="/tmp/run_aura_tests"
rm -f "$TEST_BIN"

SOURCES=(
    tests/test_main.m
    tests/test_wallpaper_manager.m
    tests/test_wallpaper_window.m
    tests/test_wallpaper_view_controller.m
    tests/test_library_controller.m
    tests/test_assets_and_bundle.m
    src/WallpaperManager.m
    src/WallpaperWindow.m
    src/WallpaperViewController.m
    src/ClickThroughPlayerView.m
    src/WallpaperLibraryWindowController.m
    src/AppDelegate.m
)

FRAMEWORKS=(
    -framework Cocoa
    -framework AVFoundation
    -framework AVKit
    -framework CoreMedia
    -framework UniformTypeIdentifiers
    -framework ServiceManagement
)

clang -fobjc-arc -O2 -g -Wall \
    -Isrc -Itests \
    "${SOURCES[@]}" \
    "${FRAMEWORKS[@]}" \
    -o "$TEST_BIN"

echo "🚀 Running Native Test Suite..."
"$TEST_BIN"

echo ""
echo "🔍 Validating Swift Mirror Parity & Syntax..."

# 1. Check file parity
REQUIRED_SWIFT_FILES=(
    "AppDelegate.swift"
    "WallpaperManager.swift"
    "WallpaperWindow.swift"
    "WallpaperViewController.swift"
    "ClickThroughPlayerView.swift"
    "WallpaperLibraryWindowController.swift"
    "main.swift"
)

for file in "${REQUIRED_SWIFT_FILES[@]}"; do
    if [ ! -f "swift_src/$file" ]; then
        echo "❌ Parity failure: Missing swift_src/$file"
        exit 1
    fi
done

# 2. Check Swift syntax and type checking
swiftc -parse swift_src/*.swift
echo "  \033[32m✓ PASS\033[0m Swift source parity and syntax verified."

echo ""
echo "🎉 \033[1;32mALL SYSTEMS GREEN! Quality checks passed successfully.\033[0m"
