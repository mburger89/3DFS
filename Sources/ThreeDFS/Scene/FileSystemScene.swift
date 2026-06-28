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

        let cols = gridColumnCount(for: fileNodes.count)
        let rows = fileNodes.isEmpty ? 0 : Int(ceil(Double(fileNodes.count) / Double(cols)))

        let newContainer = Entity()
        for (i, node) in fileNodes.enumerated() {
            let col = i % cols
            let row = i / cols
            let volume = await VolumeNode.make(fileNode: node, boxWidth: boxSize, boxDepth: boxSize, theme: theme)
            volume.position = SIMD3<Float>(Float(col) * spacing, volume.boxHeight / 2, Float(row) * spacing)
            newContainer.addChild(volume)
        }

        let totalCols = min(cols, fileNodes.count)
        let totalRows = fileNodes.isEmpty ? 0 : Int(ceil(Double(fileNodes.count) / Double(cols)))
        newContainer.position = SIMD3<Float>(
            -Float(totalCols - 1) * spacing / 2, 0,
            -Float(totalRows - 1) * spacing / 2
        )

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
