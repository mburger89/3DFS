import RealityKit
import CoreGraphics
import Foundation

@MainActor
final class FileSystemSceneManager: ObservableObject {
    let rootEntity   = Entity()   // grid + lights; on visionOS this is also rotated for orbiting
    let cameraEntity = Entity()   // PerspectiveCameraComponent (macOS / iOS only)
    let camera       = CameraController()

    private var gridContainer: Entity?
    private(set) var gridLoadCount = 0

    private let spacing: Float = 2.6
    private let boxSize:  Float = 1.9

    // MARK: - Setup (called once, before adding entities to RealityView content)

    func setup() {
        setupLights()
        setupFloor(theme: ThemeManager.shared.current)
        #if !os(visionOS)
        cameraEntity.components.set(
            PerspectiveCameraComponent(near: 0.1, far: 500, fieldOfViewInDegrees: 60)
        )
        camera.apply(to: cameraEntity)
        #endif
    }

    // MARK: - Camera

    func applyCamera() {
        #if !os(visionOS)
        camera.apply(to: cameraEntity)
        #else
        camera.applyToWorld(rootEntity)
        #endif
    }

    // MARK: - Grid

    func loadGrid(_ fileNodes: [FileNode], animated: Bool, theme: Theme) async {
        let isAnimated = animated && gridLoadCount > 0
        gridLoadCount += 1

        // On visionOS show a demo grid when the real folder is empty so there's
        // always something to look at inside the volumetric window.
        #if os(visionOS)
        let nodes = fileNodes.isEmpty ? FileSystemSceneManager.demoFileNodes() : fileNodes
        #else
        let nodes = fileNodes
        #endif

        let cols = gridColumnCount(for: nodes.count)
        let rows = nodes.isEmpty ? 0 : Int(ceil(Double(nodes.count) / Double(cols)))

        let newContainer = Entity()
        for (i, node) in nodes.enumerated() {
            let col = i % cols
            let row = i / cols
            let volume = await VolumeNode.make(fileNode: node, boxWidth: boxSize, boxDepth: boxSize, theme: theme)
            volume.position = SIMD3<Float>(Float(col) * spacing, volume.boxHeight / 2, Float(row) * spacing)
            newContainer.addChild(volume)
        }

        let totalCols = min(cols, nodes.count)
        let totalRows = nodes.isEmpty ? 0 : Int(ceil(Double(nodes.count) / Double(cols)))
        // max(0, …) prevents negative offsets when the count is zero.
        newContainer.position = SIMD3<Float>(
            -Float(max(0, totalCols - 1)) * spacing / 2, 0,
            -Float(max(0, totalRows - 1)) * spacing / 2
        )

        #if os(visionOS)
        if !nodes.isEmpty {
            // Scale the entire grid to fit within the ~0.85 m usable space of the
            // 1.2 m volumetric window. spacing/boxSize are in RealityKit meters.
            let gridW = Float(max(1, totalCols) - 1) * spacing + boxSize
            let gridD = Float(max(1, totalRows) - 1) * spacing + boxSize
            let scale = 0.85 / max(gridW, gridD)
            newContainer.scale = SIMD3<Float>(repeating: scale)
            newContainer.position.y = -0.1
        }
        #endif

        camera.resetForGrid(cols: cols, rows: rows, spacing: spacing)
        applyCamera()

        let old = gridContainer
        gridContainer = newContainer

        if isAnimated {
            newContainer.components.set(OpacityComponent(opacity: 0))
        }
        rootEntity.addChild(newContainer)

        if isAnimated {
            if let old {
                old.components.set(OpacityComponent(opacity: 1))
                let fadeOut = try? AnimationResource.makeActionAnimation(
                    for: FromToByAction<Float>(to: 0, timing: .linear, isAdditive: false),
                    duration: 0.22, bindTarget: .opacity)
                if let fadeOut { old.playAnimation(fadeOut) }
                Task { try? await Task.sleep(nanoseconds: 300_000_000); old.removeFromParent() }
            }
            let fadeIn = try? AnimationResource.makeActionAnimation(
                for: FromToByAction<Float>(to: 1, timing: .linear, isAdditive: false),
                duration: 0.28, bindTarget: .opacity)
            if let fadeIn { newContainer.playAnimation(fadeIn) }
        } else {
            old?.removeFromParent()
        }
    }

    // MARK: - Lights

    private func setupLights() {
        let ambient = Entity()
        ambient.components.set(DirectionalLightComponent(color: .white, intensity: 350))
        rootEntity.addChild(ambient)

        let key = Entity()
        key.components.set(DirectionalLightComponent(color: .white, intensity: 2500))
        key.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])
                        * simd_quatf(angle:  .pi / 5, axis: [0, 1, 0])
        rootEntity.addChild(key)

        let fill = Entity()
        fill.components.set(DirectionalLightComponent(color: .white, intensity: 400))
        fill.orientation = simd_quatf(angle: -.pi / 6, axis: [1, 0, 0])
                         * simd_quatf(angle: -.pi / 3, axis: [0, 1, 0])
        rootEntity.addChild(fill)
    }

    // MARK: - Floor

    private func setupFloor(theme: Theme) {
        // The floor is a large ground plane for the macOS perspective camera view.
        // On visionOS the content lives in a fixed-size volume, so we skip it.
        #if os(visionOS)
        return
        #else
        let mesh = MeshResource.generateBox(width: 200, height: 0.001, depth: 200, cornerRadius: 0)
        let cgColor = CGColor.from(hex: theme.scene.bottomFace)
            ?? CGColor(srgbRed: 0.05, green: 0.06, blue: 0.10, alpha: 1)
        var mat = UnlitMaterial()
        #if os(macOS)
        mat.color = .init(tint: Material.Color(cgColor: cgColor) ?? .black)
        #else
        mat.color = .init(tint: Material.Color(cgColor: cgColor))
        #endif
        let floor = ModelEntity(mesh: mesh, materials: [mat])
        floor.position = .zero
        rootEntity.addChild(floor)
        #endif
    }

    // MARK: - Helpers

    private func gridColumnCount(for count: Int) -> Int {
        max(1, Int(ceil(sqrt(Double(count)))))
    }
}

// Expose boxHeight from VolumeNodeComponent for grid positioning
private extension ModelEntity {
    var boxHeight: Float {
        components[VolumeNodeComponent.self]?.boxHeight ?? 0.12
    }
}

#if os(visionOS)
private extension FileSystemSceneManager {
    /// A curated 3×3 grid of fictional nodes shown when the real folder is empty.
    static func demoFileNodes() -> [FileNode] {
        func dir(_ name: String, children: Int, folders: Int, files: Int, top: [String]) -> FileNode {
            FileNode(url: URL(string: "file:///3DFS-demo/\(name)")!,
                     isDirectory: true, childCount: children,
                     folderCount: folders, fileCount: files, topChildren: top)
        }
        func file(_ name: String) -> FileNode {
            FileNode(url: URL(string: "file:///3DFS-demo/\(name)")!, isDirectory: false)
        }
        return [
            dir("Projects",  children: 24,  folders: 8,  files: 16,  top: ["App.swift", "ContentView.swift", "Models", "Views", "Tests"]),
            dir("Documents", children: 47,  folders: 12, files: 35,  top: ["report.pdf", "notes.md", "Budget.xlsx", "Contracts"]),
            dir("Downloads", children: 83,  folders: 3,  files: 80,  top: ["setup.dmg", "archive.zip", "photo.jpg"]),
            dir("Photos",    children: 312, folders: 18, files: 294, top: ["2024-Summer", "Vacation", "Portraits"]),
            dir("Music",     children: 156, folders: 22, files: 134, top: ["Playlists", "Albums", "Podcasts"]),
            dir("Desktop",   children: 11,  folders: 2,  files: 9,   top: ["Notes.txt", "WIP", "screenshot.png"]),
            file("README.md"),
            file("config.json"),
            file("report.pdf"),
        ]
    }
}
#endif
