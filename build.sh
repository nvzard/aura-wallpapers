#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "🔨 Building AuraWallpaper..."

APP_NAME="AuraWallpaper"
BUNDLE_DIR="$DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# 1. Clean previous build
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 2. Compile Objective-C sources
SOURCES=(
    src/main.m
    src/AppDelegate.m
    src/WallpaperManager.m
    src/WallpaperWindow.m
    src/WallpaperViewController.m
    src/ClickThroughPlayerView.m
    src/WallpaperLibraryWindowController.m
)

FRAMEWORKS=(
    -framework Cocoa
    -framework AVFoundation
    -framework AVKit
    -framework CoreMedia
    -framework UniformTypeIdentifiers
    -framework ServiceManagement
)

echo "⚙️ Compiling native binary..."
clang -fobjc-arc -O3 -g -Wall \
    "${SOURCES[@]}" \
    "${FRAMEWORKS[@]}" \
    -o "$MACOS_DIR/$APP_NAME"

# 3. Copy Plist & Resources
cp assets/Info.plist "$CONTENTS_DIR/Info.plist"

echo "📦 Bundling video wallpapers..."
for f in assets/*.mp4 assets/*.mov assets/*.m4v; do
    if [ -f "$f" ]; then
        cp -c "$f" "$RESOURCES_DIR/" 2>/dev/null || cp "$f" "$RESOURCES_DIR/"
    fi
done

# 4. Ad-hoc codesign
echo "🔏 Signing application bundle..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ Build complete: $BUNDLE_DIR"
echo ""
echo "To run the app:"
echo "  open \"$BUNDLE_DIR\""
echo ""
echo "To install to /Applications:"
echo "  cp -R \"$BUNDLE_DIR\" /Applications/"
