# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build (CLI / swift-build)
swift build

# Clean build
swift package clean && swift build

# Open in Xcode (preferred for running the app)
open 3DFS.xcodeproj
```

There are no tests. The app must be run via Xcode — `swift run` does not work for SwiftUI/AppKit macOS apps.

## Adding New Source Files

Whenever a new `.swift` file is created, it must be registered in **both** `Package.swift` (implicit — SPM picks up all files in the target path) **and** `3DFS.xcodeproj/project.pbxproj` (explicit — Xcode will fail to open/build otherwise). Three insertions are required in `project.pbxproj`:

1. **PBXBuildFile section** — a new `...AA /* Filename.swift in Sources */` entry
2. **PBXFileReference section** — a new file reference with a unique UUID
3. **PBXGroup** — add the file reference UUID under the correct group's `children`
4. **PBXSourcesBuildPhase files** — add the build file UUID

UUIDs follow the pattern `A1B2C3D4E5F6NNNN000000AA` where `NNNN` increments. After editing `project.pbxproj`, validate with `plutil -lint 3DFS.xcodeproj/project.pbxproj`.

## Platform & Concurrency

- **macOS 26 (Tahoe) only** — uses `.glassEffect()` and other APIs unavailable on earlier versions
- **Swift 6 strict concurrency** — `@MainActor` is used broadly; be careful with:
  - `SCNScene.init()` is nonisolated — wrap `@MainActor` setup calls in `MainActor.assumeIsolated { }`
  - `SCNSceneRendererDelegate` requires `@preconcurrency` on the conforming class
  - `nonisolated(unsafe)` on static `NSCache` properties (NSCache is thread-safe internally)

## Architecture

### Data Flow

```
FileNavigator (ObservableObject, @MainActor)
    └── FileSystemIndex (actor) — eager background scan, depth 4, top-8 children per dir
    └── FileSystemScanner — live directory read at navigate time, merges index data
         └── [FileNode] — passed to FileSystemScene to build the 3D grid
```

`FileNavigator` drives everything. It holds the navigation `path` stack and `currentChildren` array. Each navigation increments `epoch: UUID`, which `FileScapeSceneView.updateNSView` observes to trigger a scene reload.

### Scene Layer

```
FileScapeSceneView (NSViewRepresentable)
    └── KeyCaptureSCNView (SCNView subclass) — captures keyboard/mouse, calls back via closures
    └── FileSystemScene (SCNScene, @MainActor)
         └── CameraController — spherical coords (azimuth, elevation, distance, focusPoint)
         └── VolumeNode (SCNNode) per FileNode — SCNBox with NSImage textures
```

**VolumeNode** height is derived from `log2(childCount + 1.5) × 0.75`, clamped `[0.35, 5.5]`. Files are always `0.12` units tall. SCNBox material order is `[front, right, back, left, top, bottom]`.

**Textures** are drawn with `NSBezierPath`/Core Graphics into `NSImage` at `512 × (512 × height/width)` pixels to match each face's aspect ratio. Two `NSCache` instances (`sideTextureCache`, `fileTopTextureCache`) are keyed by `"themeName|url"` so they invalidate automatically on theme change.

**Camera** uses Shift+drag to call `slide(deltaX:deltaY:)` (moves on camera-right + world-Y, no depth). Regular drag calls `orbit`. WASD moves the focus point; Q/E zoom. Modifier state is captured at `mouseDown`, not `mouseDragged`, because `modifierFlags` is unreliable during drag.

### Theming

```
Theme (Codable, Sendable) — all colors as hex strings (#RRGGBB / #RRGGBBAA)
ThemeManager (@MainActor, ObservableObject, singleton)
    └── 4 built-in themes (Theme.builtIn)
    └── customThemes — loaded from ~/Library/Application Support/3DFS/Themes/
ThemeEditorView — detached Window scene ("theme-editor"), live preview via ThemeManager.current
YAMLThemeParser — simple line-by-line YAML→JSON converter (no external deps)
```

Colors are stored as `String` (not `NSColor`) to keep `Theme` `Codable` and `Sendable`. Use `NSColor(hex:)` (defined in `Theme.swift`) to convert for drawing. In YAML theme files, hex colors **must be quoted** because `#` is a YAML comment character.

The theme editor window is registered as a `Window("Theme Editor", id: "theme-editor")` scene in `FileScapeApp.swift` and opened with `@Environment(\.openWindow)`. Changes apply live — picking a color immediately sets `ThemeManager.current`.

### Access Model

On launch, `FileNavigator.init()` tries three paths in order:
1. Full Disk Access granted → start from `~` directly
2. Security-scoped bookmark in UserDefaults → restore previous root
3. Neither → show `WelcomeView` for user to grant FDA or pick a folder

`WelcomeView` is shown when `navigator.needsRootSelection == true`.
