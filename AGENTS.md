# AGENTS.md - AuraWallpaper Development Guide

Lightweight macOS status-bar dynamic wallpaper engine (`LSUIElement`) playing seamless looping video behind Finder desktop icons.

---

## ⚡ Essential Commands

```bash
# Run automated test suite (Unit & Integration tests + Swift parity check)
./test.sh

# Build app bundle (AuraWallpaper.app)
./build.sh

# Restart / Test app
pkill -x AuraWallpaper 2>/dev/null || true; open AuraWallpaper.app

# Run directly in terminal for stderr/NSLog debugging
./AuraWallpaper.app/Contents/MacOS/AuraWallpaper

# Check running process
pgrep -l AuraWallpaper
```

---

## 🗂️ Architecture & Codebase Map

| Path | Purpose |
| :--- | :--- |
| `src/` | **Primary active codebase** (Objective-C/Cocoa ARC). Compiled by `build.sh` via `clang`. |
| `swift_src/` | **Pure Swift 1:1 mirror**. Must be kept in architectural and feature parity with `src/`. |
| `tests/` | **Automated test suite**. Modular unit and integration tests executed by `test.sh`. |
| `assets/` | Bundle configuration (`Info.plist`) and bundled video (`default_wallpaper.mp4`). |
| `build.sh` | Shell build script compiling `src/*.m`, linking frameworks, copying assets, and ad-hoc codesigning. |
| `test.sh` | Automated test runner script compiling `tests/*.m`, running assertions, and validating Swift mirror parity. |

### Component Hierarchy

1. **`AppDelegate`** (`src/AppDelegate.m`, `swift_src/AppDelegate.swift`)
   - Manages status item (`sparkles.tv`) and menu.
   - Controls: Open Wallpaper Library, Pause/Resume, Mute/Unmute, Hide Desktop Icons, Open at Login (`SMAppService`).
2. **`WallpaperManager`** (`src/WallpaperManager.m`, `swift_src/WallpaperManager.swift`)
   - Central singleton orchestrator.
   - Observes display topology changes (`NSApplicationDidChangeScreenParametersNotification`).
   - Observes power/sleep notifications (`NSWorkspaceScreensDidSleepNotification`, `NSWorkspaceWillSleepNotification`, wake events) to pause/resume playback.
   - Manages window lifecycle; reuses existing screen windows on wallpaper change to avoid flicker.
   - Scans available wallpapers (bundled + user application support) and handles import/delete.
3. **`WallpaperWindow`** (`src/WallpaperWindow.m`, `swift_src/WallpaperWindow.swift`)
   - Borderless, transparent, non-activating window per `NSScreen`.
   - Normal level: `CGWindowLevelForKey(kCGDesktopWindowLevelKey)` (behind Finder icons).
   - Hide icons level: `CGWindowLevelForKey(kCGOverlayWindowLevelKey) + 1` (covers Finder icons).
   - Settings: `canBecomeKeyWindow = NO`, `canBecomeMainWindow = NO`, `releasedWhenClosed = NO`, `ignoresMouseEvents = YES`.
   - Behavior: `NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle`.
4. **`WallpaperViewController`** (`src/WallpaperViewController.m`, `swift_src/WallpaperViewController.swift`)
   - Hosts `AVQueuePlayer` + `AVPlayerLooper` for hardware-accelerated zero-gap looping.
   - Extracts first video frame and syncs with `NSWorkspace.sharedWorkspace.setDesktopImageURL` to eliminate black flashes on wake/space-switch.
5. **`ClickThroughPlayerView`** (`src/ClickThroughPlayerView.m`, `swift_src/ClickThroughPlayerView.swift`)
   - Subclass of `AVPlayerView` overriding `hitTest:` to return `nil`, passing clicks to Finder.
6. **`WallpaperLibraryWindowController`** (`src/WallpaperLibraryWindowController.m`, `swift_src/WallpaperLibraryWindowController.swift`)
   - Responsive visual gallery window featuring frosted backdrop (`NSVisualEffectView`).
   - Displays 16:9 async video thumbnails with active checkmarks and hover effects.
   - Immediate click-to-apply switching and "+ Add Wallpaper..." local file importer.

---

## ⚠️ Critical Rules & Gotchas

1. **Dual-Stack Parity**: When introducing features, bugfixes, or refactoring in `src/`, always apply matching updates to `swift_src/`.
2. **AVPlayerLooper Teardown**: Before reallocating or loading new video, always invoke `[playerLooper disableLooping]`, `playerView.player = nil`, `[player pause]`, and `[player removeAllItems]` to prevent zombie audio/playback and memory leaks.
3. **Window Reuse**: When changing wallpaper URL, check if existing `windows.count == screens.count`. If matching, reuse windows and call `loadVideoURL:` rather than tearing down and rebuilding `WallpaperWindow`s.
4. **Main Thread Only**: All UI, `NSWindow`, and `WallpaperManager` mutations must run on `dispatch_get_main_queue()`.
5. **Linked Frameworks**: Cocoa, AVFoundation, AVKit, CoreMedia, UniformTypeIdentifiers, ServiceManagement.
