# Deep-Dive Analysis: macOS Dynamic Wallpaper Architecture

This document contains the reverse-engineering analysis of `/Applications/dynamicwallpaper.app` (`com.zhou.dynamicwallpaper`), explaining how dynamic/live wallpaper engines operate on macOS at the system level, and how to build a 100% free, open-source alternative.

---

## 1. Executive Summary

Commercial macOS dynamic wallpaper applications (such as Dynamic Wallpaper Engine, Live Desktop, etc.) appear to modify Finder or replace the desktop. In reality, **macOS provides no public API to directly render video onto the native desktop layer**.

Instead, these apps use an elegant combination of:
1. **Low-Level Window Hierarchy Tricks (`CGWindowLevel`)**: Placing a borderless, transparent `NSWindow` directly behind Finder's icon layer (`kCGDesktopWindowLevelKey`).
2. **Hit Testing Passthrough**: Overriding AppKit mouse hit-testing (`hitTest: -> nil`) so all user interaction (desktop icon clicks, box selections, right-click context menus) pass seamlessly to Finder.
3. **Hardware-Accelerated Looping**: Leveraging `AVFoundation` (`AVQueuePlayer`, `AVPlayerLooper`, `AVPlayerItem`) for GPU-accelerated video decoding.
4. **Occlusion & Power Throttling**: Pausing playback during display sleep, lock screen, or when full-screen applications cover the desktop to save battery.
5. **Static Preview Synchronization**: Setting macOS's native static wallpaper (`NSWorkspace.setDesktopImageURL`) to the video's first frame to prevent black flash artifacts during boot, wake, or Mission Control transitions.

The paywall in commercial apps comes from remote video hosting (via `CloudKit`) and in-app purchase subscriptions (via `StoreKit`). The core live wallpaper engine itself is built entirely on free, native macOS AppKit and AVFoundation frameworks.

---

## 2. Reverse Engineering `/Applications/dynamicwallpaper.app`

### 2.1 Bundle & Dependency Inspection

Inspection of the app bundle structure and Mach-O header reveals:
* **Bundle Identifier**: `com.zhou.dynamicwallpaper`
* **Version**: `1.1.7` (Universal binary: `x86_64` + `arm64`)
* **Agent Mode**: `LSUIElement = true` in `Info.plist` (runs quietly in the menu bar with no Dock icon).
* **Linked Frameworks**:
  * `AVFoundation.framework` & `AVKit.framework`: Video decoding and rendering.
  * `AppKit.framework`: Window management, status item (menu bar), screen geometry.
  * `CoreGraphics.framework`: Window levels and display reconfigurations.
  * `IOKit.framework`: Sleep/wake and power state detection.
  * `CloudKit.framework`: Remote catalog synchronization.
  * `StoreKit.framework`: In-App purchases / VIP subscriptions.

### 2.2 Core Objective-C Classes

Through Mach-O runtime introspection (`otool -ov`), the architecture is structured into the following core classes:

```
┌─────────────────────────────────────────────────────────────┐
│                         AppDelegate                         │
│   • NSStatusItem (Menu Bar)                                 │
│   • Sleep/Wake Notification Center Observers                │
│   • Volume / Mute Controls                                  │
│   • "Hide Desktop Icons" Toggle                             │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
               ▼                              ▼
┌──────────────────────────────┐ ┌────────────────────────────┐
│      WallpaperWindow         │ │    OcclusionWindow         │
│   • Level: kCGDesktopWindow  │ │    Controller              │
│   • Behavior: 0x51           │ │    • Observes              │
│   • Content: WallpaperVC     │ │      OcclusionState        │
└──────────────┬───────────────┘ └────────────┬───────────────┘
               │                              │
               ▼                              │
┌──────────────────────────────┐              │
│     NoMouseAVPlayerView      │              │
│   • hitTest: returns nil     │              │
│   • videoGravity: AspectFill │              │
└──────────────┬───────────────┘              │
               │                              │
               ▼                              ▼
┌─────────────────────────────────────────────────────────────┐
│                            Tools                            │
│   • updatePlayState: pauses/resumes AVPlayer based on       │
│     isSleep, isOcclusion, and isConnection                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. How It Works: Technical Deep Dive

### 3.1 Window Positioning & Levels (`CGWindowLevel`)

macOS organizes windows into hierarchical layers defined by `CGWindowLevelForKey`. The decompiled assembly of `-[WallpaperWindowController hiddenDesktopIcon]` and `-[WallpaperWindowController windowDidLoad]` reveals the exact window levels used:

```assembly
## From WallpaperWindowController hiddenDesktopIcon:
movq    $-0x7fffffe7, %rax    ## 0x80000019 = -2147483623 (kCGDesktopWindowLevelKey)
movq    $-0x7fffffd2, %rcx    ## 0x8000002E = -2147483602 (kCGDesktopIconWindowLevelKey + 1)
movq    0x31d69(%rip), %rsi   ## -[NSWindow setLevel:]
```

#### Window Level Comparison Table

| Mode | Window Level Key | Level Value | Layer Behavior |
| :--- | :--- | :--- | :--- |
| **Standard Mode** | `kCGDesktopWindowLevelKey` | `-2147483623` (`0x80000019`) | Sits behind desktop icons and Finder widgets. Icons remain visible and usable. |
| **Hide Icons Mode** | `kCGNormalWindowLevelKey - 1` | `-1` (`0xFFFFFFFF`) | Sits *above* desktop icons and WindowServer `underbelly` (-2147483602), strictly below normal applications (0). Eliminates menu bar fade flickering. |
| **Screensaver Mode**| `kCGPopUpMenuWindowLevelKey` | `1000` (`0x000003E8`) | Sits above all normal applications, filling the screen. |

### 3.2 Collection Behavior: Space & Mission Control Persistence

To make the wallpaper window remain visible across all virtual desktops (Spaces) and during Mission Control transitions without participating in application cycling, the app configures:

```assembly
movl    $0x51, %edx
movq    0x32269(%rip), %rsi    ## -[NSWindow setCollectionBehavior:]
```

The value `0x51` is the bitwise OR of three AppKit flags:
* `NSWindowCollectionBehaviorCanJoinAllSpaces` (`0x01`): Present on all Spaces / Desktops.
* `NSWindowCollectionBehaviorStationary` (`0x10`): Does not move or minimize when Mission Control opens.
* `NSWindowCollectionBehaviorIgnoresCycle` (`0x40`): Excluded from `Cmd + Tab` and `Cmd + `~`` window cycling.

### 3.3 Mouse Click-Through (`NoMouseAVPlayerView`)

To prevent the video player window from intercepting clicks meant for the desktop icons, `NoMouseAVPlayerView` overrides `hitTest:`:

```assembly
## -[NoMouseAVPlayerView hitTest:]
pushq   %rbp
movq    %rsp, %rbp
xorl    %eax, %eax     ## Return 0 (nil)
popq    %rbp
retq
```

In Objective-C / Swift terms:
```swift
override func hitTest(_ point: NSPoint) -> NSView? {
    return nil // Never accept mouse events; pass directly through to Finder
}
```
Combined with `window.ignoresMouseEvents = true`, the window is 100% transparent to mouse events, allowing desktop icon selection, right-click desktop menus, and drag-and-drop.

### 3.4 Hardware-Accelerated Video Playback & Media Center Decoupling

In `-[WallpaperViewController writeFinishStartPlay:]`:
1. **Asset Creation**: `AVURLAsset` -> `AVPlayerItem` -> `AVPlayer`.
2. **Layer Configuration**: `videoGravity = AVLayerVideoGravityResizeAspectFill`.
3. **Looping**: Re-seeks to `kCMTimeZero` on `AVPlayerItemDidPlayToEndTimeNotification` or uses `AVPlayerLooper`.
4. **Media Control Isolation**:
   ```assembly
   movq    0x338fc(%rip), %rsi    ## setUpdatesNowPlayingInfoCenter:
   xorl    %edx, %edx             ## NO (false)
   ```
   Setting `updatesNowPlayingInfoCenter = false` is critical: it prevents the wallpaper video from showing up in macOS Control Center, the lock screen media widget, or taking over keyboard Play/Pause media keys.

### 3.5 Occlusion Culling & Power Efficiency (`Tools updatePlayState`)

Playing video on large Retina / 4K displays requires GPU memory and decode cycles. To prevent battery drain, the app implements an active state machine:

```
                  ┌──────────────────────┐
                  │ State Change Trigger │
                  └──────────┬───────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       ▼                     ▼                     ▼
Screen Sleep / Lock   Space Switched /      Full-Screen App
Notification          Multi-Monitor Changed Covers Desktop
       │                     │                     │
       ▼                     ▼                     ▼
  player.pause()       Check Geometry        player.pause()
(0% GPU / Decode)     Rebind Displays      (Save CPU/Battery)
```

The system observes:
* `NSWorkspaceScreensDidSleepNotification`: Immediately calls `[player pause]`.
* `NSWorkspaceScreensDidWakeNotification`: Calls `[player play]`.
* `NSWorkspaceActiveSpaceDidChangeNotification`: Re-evaluates visibility.
* `NSWindowDidChangeOcclusionStateNotification`: Checks if `(window.occlusionState & NSWindowOcclusionStateVisible)` is zero. If occluded, it pauses playback.

### 3.6 First-Frame Static Wallpaper Trick

When macOS starts up or switches users, dynamic windows take 100–300ms to instantiate. If the native desktop background behind the window is default, the user experiences a jarring visual flash.

To fix this, the app uses `AVAssetImageGenerator` to extract the first video frame as a static image, then invokes:
```objc
[[NSWorkspace sharedWorkspace] setDesktopImageURL:frameURL
                                        forScreen:screen
                                          options:@{}
                                            error:&error];
```
This ensures that the underlying static desktop image perfectly matches the first frame of the video, creating an imperceptible transition when video playback starts.

---

## 4. How to Build the Free Alternative (`AuraWallpaper`)

A complete, free alternative requires zero paid libraries and zero external dependencies. The core architecture comprises 5 modular components:

### Component Architecture

1. **`WallpaperWindow`**: Borderless, non-activating window at `kCGDesktopWindowLevelKey` with collection behavior `0x51`.
2. **`ClickThroughPlayerView`**: Subclass of `AVPlayerView` returning `nil` from `hitTest:`.
3. **`WallpaperManager`**: Coordinates multiple monitors (`NSScreen.screens`), listens for display reconfiguration, and manages video playback.
4. **`PowerObserver`**: Detects sleep, wake, and occlusion to pause/resume playback.
5. **`AppDelegate`**: Menu bar item (`NSStatusItem`) providing quick settings:
   - Select Video File (`.mp4`, `.mov`, `.m4v`).
   - Play / Pause toggle.
   - Mute / Audio volume slider.
   - "Hide Desktop Icons" toggle.
   - "Open at Login" toggle (macOS `SMAppService`).
   - Quit.

---

## 5. Architectural Comparison

| Dimension | `/Applications/dynamicwallpaper.app` | Free Alternative (`AuraWallpaper`) |
| :--- | :--- | :--- |
| **Cost** | Free app with paid subscriptions ($1.99 - $19.99) | 100% Free & Open-Source |
| **Video Source** | Proprietary CloudKit gallery | Any local `.mp4`, `.mov`, or free web sources |
| **Decoders** | Hardware `AVFoundation` | Hardware `AVFoundation` |
| **Battery Consumption** | Low (occlusion & sleep pausing) | Ultra-Low (optimized state machine) |
| **Desktop Icons** | Selectable (behind or above icons) | Selectable (behind or above icons) |
| **Multi-Display** | Supported | Supported (auto-adapts to monitor plug/unplug) |
| **Footprint** | Heavy (StoreKit, CloudKit, Analytics, Ad views) | Minimal (< 2 MB native binary) |
| **Dock Visibility** | `LSUIElement = true` (Menu bar only) | `LSUIElement = true` (Menu bar only) |
