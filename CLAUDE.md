# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build (CLI / swift-build) — compiles the macOS target only, useful for quick syntax/type checks
swift build

# Clean build
swift package clean && swift build

# Open in Xcode (required for actually running the app)
open 3DFS.xcodeproj
```

There are no tests. The app must be run via Xcode (⌘R) — `swift run` does not work for SwiftUI/RealityKit apps, and `Package.swift` only declares a macOS target (the real app also ships to visionOS via the Xcode project, which `swift build` cannot exercise).

CI (`.github/workflows/release.yml`) builds releases via `xcodebuild archive -project 3DFS.xcodeproj -scheme 3DFS -configuration Release` on tag push and attaches the zipped `.app` to a GitHub Release.

## Adding New Source Files

Whenever a new `.swift` file is created, it must be registered in **both** `Package.swift` (implicit — SPM picks up all files in the target path) **and** `3DFS.xcodeproj/project.pbxproj` (explicit — Xcode will fail to open/build otherwise). Four insertions are required in `project.pbxproj`:

1. **PBXBuildFile section** — a new `...AA /* Filename.swift in Sources */` entry
2. **PBXFileReference section** — a new file reference with a unique UUID
3. **PBXGroup** — add the file reference UUID under the correct group's `children`
4. **PBXSourcesBuildPhase files** — add the build file UUID

UUIDs follow the pattern `A1B2C3D4E5F6NNNN000000AA` where `NNNN` increments. After editing `project.pbxproj`, validate with `plutil -lint 3DFS.xcodeproj/project.pbxproj`.

## Platform & Concurrency

- **Multiplatform: macOS 26 (Tahoe) + visionOS** — `SUPPORTED_PLATFORMS = "macosx xros xrsimulator"` in the Xcode project (`TARGETED_DEVICE_FAMILY = 7`). `Package.swift` only lists `.macOS(.v26)` since SPM can't express the visionOS target — don't treat it as the platform list.
- Code forks on `#if os(macOS)` for AppKit-only features (Full Disk Access, `NSAlert`/`NSSavePanel`/`NSOpenPanel` theme import/export, WASD keyboard panning, `.glassEffect()`) and on `#if !os(visionOS)` / `#if os(visionOS)` for the camera model (see Scene Layer below). Non-macOS platforms fall back to `.background(.regularMaterial, ...)` instead of `.glassEffect()`.
- **Swift 6 strict concurrency** — `@MainActor` is used broadly; be careful with:
  - `nonisolated(unsafe)` on the static `NSCache<NSString, TextureResource>` in `VolumeNode` (NSCache is thread-safe internally)
  - `FileSystemIndex` is a plain `actor` (not `@MainActor`) since it does background disk scanning independent of the UI

## Architecture

### Data Flow

```
FileNavigator (ObservableObject, @MainActor)
    └── FileSystemIndex (actor) — eager background scan, depth 4, top-8 children per dir
    └── FileSystemScanner — live directory read at navigate time, merges index data
         └── [FileNode] — passed to FileSystemSceneManager to build the 3D grid
```

`FileNavigator` drives everything. It holds the navigation `path` stack and `currentChildren` array. Each navigation increments `epoch: UUID`; `FileScapeSceneView` keys a `.task(id:)` on `"\(epoch)|\(themeManager.current.name)"` so both navigation and theme changes trigger `scene.loadGrid(...)`.

### Scene Layer — RealityKit (not SceneKit)

The 3D scene is built entirely on RealityKit/`Entity`, driven from a SwiftUI `RealityView`:

```
FileScapeSceneView (SwiftUI View, wraps RealityView)
    └── FileSystemSceneManager (ObservableObject, @MainActor) — owns rootEntity + cameraEntity
         └── CameraController — spherical coords (azimuth, elevation, distance, focusPoint)
         └── VolumeNode (enum factory) — builds a ModelEntity per FileNode, tagged with VolumeNodeComponent
```

- **Camera is platform-dependent.** On macOS/iOS, `cameraEntity` carries a `PerspectiveCameraComponent` and `CameraController.apply(to:)` moves/orients that entity. On **visionOS there is no camera entity** (the user's head is the camera); instead `CameraController.applyToWorld(_:)` rotates/translates `rootEntity` itself to simulate orbiting. `FileSystemSceneManager.applyCamera()` picks the right one via `#if !os(visionOS)`.
- **Input** is plain SwiftUI gestures on the `RealityView`, not a custom `NSView`/mouse-capture subclass: `DragGesture` → `camera.orbit`, `MagnifyGesture` (pinch) → `camera.zoom`, `TapGesture().targetedToAnyEntity()` → walks up the entity hierarchy looking for `VolumeNodeComponent` and calls `navigator.navigateTo(_:)` if it's a directory. WASD/Q/E panning and zoom are macOS-only, driven by `.onKeyPress` tracking a `keysDown` set polled by a 60fps `Timer` (`handleWASD()`), all inside `#if os(macOS)`.
- **VolumeNode** height is `log2(childCount + 1.5) × 0.75`, clamped `[0.35, 5.5]`. Files are always `0.12` units tall. The box mesh uses `MeshResource.generateBox(splitFaces: true)`, whose material array order is **`[front, top, back, bottom, right, left]`** — note this differs from SceneKit's `SCNBox` face order, so don't assume the old ordering when touching `VolumeNode.make`.
- **Materials**: directory tops are `PhysicallyBasedMaterial` (emissive, from `theme.directory.topColor`/`topEmission`); everything else (sides, file tops, floor) is `UnlitMaterial`/`SimpleMaterial` with a `TextureResource` built from a Core Graphics/Core Text-drawn `CGImage` (`drawSideTexture`, `drawFileSideTexture`, `drawFileTopTexture`). There is a single `NSCache<NSString, TextureResource>` keyed `"<face>|<themeName>|<url.path>"` (e.g. `"side|Default|/Users/x/foo"`) so entries invalidate automatically on theme change.
- Grid reloads fade the old container out and the new one in via `OpacityComponent` + `AnimationResource.makeActionAnimation`, gated by `animated: gridLoadCount > 0` so the very first load doesn't animate.

### Theming

```
Theme (Codable, Sendable) — all colors as hex strings (#RRGGBB / #RRGGBBAA)
ThemeManager (@MainActor, ObservableObject, singleton)
    └── 4 built-in themes (Theme.builtIn: Default, Vapor Wave, Forest, Midnight)
    └── customThemes — loaded from ~/Library/Application Support/3DFS/Themes/
ThemeEditorView — detached Window scene ("theme-editor", macOS only), live preview via ThemeManager.current
YAMLThemeParser — simple line-by-line YAML→JSON converter (no external deps)
```

Colors are stored as `String` (not `NSColor`/`CGColor`) to keep `Theme` `Codable` and `Sendable`. Use `CGColor.from(hex:)` (cross-platform) or `NSColor(hex:)` (macOS-only, both in `Theme.swift`) to convert for drawing. In YAML theme files, hex colors **must be quoted** because `#` is a YAML comment character. Theme import/export (`ThemeManager.importTheme()`/`exportTheme(_:)`) and the Theme Editor window are macOS-only (`#if os(macOS)`) — visionOS/iOS can only pick between built-in themes plus any custom themes already dropped in the Application Support folder.

The theme editor window is registered as a `Window("Theme Editor", id: "theme-editor")` scene in `FileScapeApp.swift` (only inside the macOS branch of `ThreeDFSApp.body`) and opened with `@Environment(\.openWindow)`. Changes apply live — picking a color immediately sets `ThemeManager.current`.

### Access Model

On launch, `FileNavigator.init()` tries (macOS):
1. Full Disk Access granted (`FullDiskAccessHelper.check()`) → start from `~` directly
2. Security-scoped bookmark in UserDefaults → restore previous root
3. Neither → show `WelcomeView` for the user to grant FDA or pick a folder

On non-macOS platforms there is no FDA path — only the security-scoped bookmark and folder picker apply. `WelcomeView` is shown when `navigator.needsRootSelection == true`; its Full Disk Access card is itself `#if os(macOS)`-only.
