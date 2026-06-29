# 3DFS

A macOS app that visualizes your file system as an interactive 3D grid of volumes. Directories are rendered as boxes whose height reflects the number of children inside them; files appear as flat slabs. Navigate by clicking into folders, orbiting the camera, and flying through your file system in three dimensions.

Built with SwiftUI, SceneKit, and macOS 26's Liquid Glass APIs.

---

## Features

- **3D file system visualization** — directories scale in height by child count, files are always flat
- **Keyboard & mouse navigation** — orbit, pan, zoom, and fly with WASD / Q / E
- **Breadcrumb trail** — shows your current path and lets you jump back to any ancestor
- **Theming** — four built-in themes, a live theme editor, and support for custom YAML themes
- **Full Disk Access or folder picker** — browse your entire home directory or scope to a specific folder
- **Background indexing** — a background actor pre-scans up to 4 levels deep so navigation feels instant

## Controls

| Input | Action |
|-------|--------|
| Left drag | Orbit camera |
| Shift + drag | Pan (slide) |
| Two-finger scroll | Pan |
| Pinch / Q / E | Zoom |
| WASD | Move focus point |
| Click a volume | Enter directory |
| ⌘[ | Go back |

---

## Requirements

- **macOS 26 (Tahoe)** or later — uses `.glassEffect()` and other Tahoe-only APIs
- **Xcode 26** or later
- Swift 6

## Building

Clone the repo and open the project in Xcode:

```bash
git clone https://github.com/mburger89/3DFS
cd 3DFS
open 3DFS.xcodeproj
```

Then press **⌘R** to build and run. The app cannot be launched with `swift run` because it is a SwiftUI/AppKit macOS app.

For a command-line build check (no UI):

```bash
swift build
```

## Theming

Themes are defined as YAML files and stored in:

```
~/Library/Application Support/3DFS/Themes/
```

All hex color values must be quoted (e.g. `"#FF0000"`) because `#` is a YAML comment character. Open **Theme Editor…** from the palette menu in the toolbar to create and preview themes live.

A theme file covers three sections: `scene`, `directory`, and `file`. See `3DFS-Theme-Guide.md` for the full field reference.

---

## Project Structure

```
Sources/ThreeDFS/
├── FileScapeApp.swift          # App entry point, window scenes
├── ContentView.swift           # Root view + toolbar
├── FileNavigator.swift         # Navigation state (ObservableObject)
├── FullDiskAccessHelper.swift  # FDA detection & System Settings prompt
├── Models/
│   └── FileNode.swift          # File/directory data model
├── Scanner/
│   ├── FileSystemScanner.swift # Live directory read at navigate time
│   └── FileSystemIndex.swift   # Background pre-scan actor
├── Scene/
│   ├── FileScapeSceneView.swift # NSViewRepresentable bridge
│   ├── FileSystemScene.swift    # SCNScene — builds the 3D grid
│   ├── VolumeNode.swift         # SCNNode subclass for each file/dir
│   ├── CameraController.swift   # Spherical camera (orbit/pan/zoom)
│   └── KeyCaptureSCNView.swift  # SCNView subclass for keyboard input
├── Theming/
│   ├── Theme.swift              # Codable theme model
│   ├── ThemeManager.swift       # Singleton, built-in + custom themes
│   ├── ThemeEditorView.swift    # Live theme editor window
│   └── YAMLThemeParser.swift    # Lightweight YAML → JSON parser
└── Views/
    ├── BreadcrumbBar.swift      # Path breadcrumb strip
    └── WelcomeView.swift        # First-launch access flow
```

---

## Contributing

1. Fork the repo and create a feature branch
2. Open `3DFS.xcodeproj` in Xcode 26+
3. Make your changes — the project uses **Swift 6 strict concurrency**, so `@MainActor` isolation is enforced throughout
4. When adding a new `.swift` file, register it in `3DFS.xcodeproj/project.pbxproj` (see `CLAUDE.md` for the exact steps — Xcode will fail to build if this is skipped)
5. Validate the project file after any manual edits: `plutil -lint 3DFS.xcodeproj/project.pbxproj`
6. Open a pull request with a clear description of the change

### Key conventions

- `@MainActor` is used broadly — wrap nonisolated SceneKit setup in `MainActor.assumeIsolated { }`
- Colors in themes are stored as hex strings, not `NSColor`, to keep `Theme` `Codable` and `Sendable`
- Texture caches (`NSCache`) are keyed `"themeName|url"` so they automatically invalidate on theme change
- `SCNSceneRendererDelegate` conformances need `@preconcurrency`
