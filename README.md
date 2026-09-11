# AuraWallpaper - Free & Lightweight Live Wallpaper for macOS

A 100% free, open-source dynamic wallpaper engine for macOS that plays looping video wallpapers with zero subscriptions and zero bloat.

Built after reverse-engineering commercial macOS dynamic wallpaper apps. See [`ANALYSIS.md`](ANALYSIS.md) for the technical analysis.

---

## ✨ Features

- **Behind Desktop Icons**: Sits at `kCGDesktopWindowLevelKey` so Finder desktop icons, drag-and-drop, and marquee selections remain functional.
- **Click-Through Transparency**: Mouse hit-testing returns `nil` so clicks pass straight through to Finder.
- **Multi-Monitor Support**: Automatically mirrors or handles dynamic wallpapers on all connected displays (`NSScreen.screens`), dynamically reacting to monitor connects/disconnects.
- **Menu Bar Companion**: Runs quietly in your status bar (`LSUIElement = true`) with zero Dock clutter.
- **Hardware Accelerated**: Uses native `AVFoundation` (`AVQueuePlayer` + `AVPlayerLooper`) with Apple Silicon hardware video decoding.
- **Battery & Sleep Aware**: Automatically pauses video playback on screen sleep/lock and resumes on wake.
- **Hide Desktop Icons Mode**: One-click toggle in the menu bar to elevate the wallpaper above desktop icons for a clean workspace.
- **Open at Login**: Built-in login item management via macOS `SMAppService` with zero background helpers required.
- **Audio Control**: Support for video audio with instantaneous mute/unmute toggle.
- **Zero Black Flash**: Extracts the first frame and synchronizes macOS's static desktop image so switching spaces or unlocking doesn't flash.

---

## 🚀 Quick Start

### Build & Package
Run the build script to compile and generate `AuraWallpaper.app`:
```bash
./build.sh
```

### Launch the App
```bash
open AuraWallpaper.app
```

### Install to Applications (Optional)
```bash
cp -R AuraWallpaper.app /Applications/
```

---

## 🎮 Menu Bar Controls

Click the `✨` icon in the macOS menu bar to:
1. **Choose Video Wallpaper...**: Pick any local `.mp4`, `.mov`, `.m4v`, or `.webm` video.
2. **Pause / Resume Wallpaper**: Instantly stop/start video playback.
3. **Mute / Unmute Audio**: Toggle video sound.
4. **Hide Desktop Icons**: Toggle between showing and hiding desktop icons.
5. **Open at Login**: Toggle whether AuraWallpaper launches automatically upon macOS user login.
6. **Quit Aura Wallpaper**: Clean exit.

---

## 🏗️ Architecture

```
live-wallpapers-mac/
├── ANALYSIS.md                        # Reverse engineering analysis document
├── README.md                          # Project documentation
├── build.sh                           # Native compiler script
├── AuraWallpaper.app/                 # Compiled standalone macOS application
├── assets/
│   ├── Info.plist                     # App bundle configuration
│   └── default_wallpaper.mp4          # Default bundled starter video
├── src/                               # Native Objective-C / Cocoa engine
│   ├── main.m                         # Application entrypoint
│   ├── AppDelegate.h / .m             # Menu bar status item & actions
│   ├── WallpaperManager.h / .m        # Multi-screen & power orchestrator
│   ├── WallpaperWindow.h / .m         # Borderless transparent desktop-level window
│   ├── WallpaperViewController.h / .m # AVPlayerLooper hardware playback controller
│   └── ClickThroughPlayerView.h / .m  # AVPlayerView hitTest passthrough
└── swift_src/                         # Pure Swift equivalent implementation
    ├── main.swift
    ├── AppDelegate.swift
    ├── WallpaperManager.swift
    ├── WallpaperWindow.swift
    ├── WallpaperViewController.swift
    └── ClickThroughPlayerView.swift
```

---

## 📜 License
MIT License. Free to use, modify, and distribute.
