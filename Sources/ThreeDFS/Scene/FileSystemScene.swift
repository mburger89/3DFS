import RealityKit
import CoreGraphics
import Foundation
import Observation
import simd

@MainActor
@Observable
final class FileSystemSceneManager {
    let rootEntity   = Entity()   // grid + lights; on visionOS this is also rotated for orbiting
    let cameraEntity = Entity()   // PerspectiveCameraComponent (macOS / iOS only)
    let camera       = CameraController()

    @ObservationIgnored private var gridContainer: Entity?
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

    // MARK: - Aim & hover preview (macOS/iOS only — visionOS has no fixed camera
    // transform to raycast from, and gaze isn't exposed to app code; gaze + pinch
    // there already provides look-and-select via the existing tap gesture)
    //
    // Both the gamepad reticle and mouse hover feed into the same `setAimed(_:index:)`,
    // so aiming at a directory by either method halves its box and stacks a shrunk
    // replica of its own contents on top as a peek before diving in.

    #if !os(visionOS)
    private(set) var aimedEntity: Entity?
    @ObservationIgnored private var previewContainer: Entity?
    @ObservationIgnored private var previewTask: Task<Void, Never>?

    var aimedFileNode: FileNode? {
        aimedEntity?.components[VolumeNodeComponent.self]?.fileNode
    }

    /// Raycasts from the camera through the fixed, screen-center reticle (gamepad).
    func updateReticleAim(index: FileSystemIndex) {
        setAimed(volume(alongOrigin: cameraEntity.position(relativeTo: nil), direction: camera.forwardDirection), index: index)
    }

    /// Raycasts from the camera through an arbitrary screen point (mouse/trackpad).
    func updateHoverAim(screenPoint: CGPoint, viewSize: CGSize, index: FileSystemIndex) {
        guard viewSize.width > 0, viewSize.height > 0,
              let fov = cameraEntity.components[PerspectiveCameraComponent.self]
        else { return }

        let ndcX = Float(screenPoint.x / viewSize.width) * 2 - 1
        let ndcY = 1 - Float(screenPoint.y / viewSize.height) * 2
        let aspect = Float(viewSize.width / viewSize.height)
        let tanHalfFovY = tan(fov.fieldOfViewInDegrees * .pi / 180 / 2)

        let localDir = SIMD3<Float>(ndcX * tanHalfFovY * aspect, ndcY * tanHalfFovY, -1)
        let worldDir = normalize(cameraEntity.orientation(relativeTo: nil).act(localDir))
        setAimed(volume(alongOrigin: cameraEntity.position(relativeTo: nil), direction: worldDir), index: index)
    }

    func clearAim() {
        endPreview(restoring: aimedEntity)
        aimedEntity = nil
    }

    private func setAimed(_ target: Entity?, index: FileSystemIndex) {
        guard target !== aimedEntity else { return }
        endPreview(restoring: aimedEntity)
        guard let target, let comp = target.components[VolumeNodeComponent.self], comp.fileNode.isDirectory else {
            aimedEntity = nil
            return
        }
        aimedEntity = target
        beginPreview(for: target, fileNode: comp.fileNode, boxHeight: comp.boxHeight, index: index)
    }

    private func beginPreview(for entity: Entity, fileNode: FileNode, boxHeight: Float, index: FileSystemIndex) {
        var halved = entity.transform
        halved.scale.y = 0.5
        halved.translation.y = boxHeight / 4
        entity.move(to: halved, relativeTo: entity.parent, duration: 0.18, timingFunction: .easeInOut)

        let container = Entity()
        container.position = SIMD3<Float>(entity.position.x, boxHeight / 2 + 0.04, entity.position.z)
        entity.parent?.addChild(container)
        previewContainer = container

        let theme = ThemeManager.shared.current
        previewTask = Task { [weak self] in
            let children = await FileSystemScanner.scan(url: fileNode.url, index: index)
            guard !Task.isCancelled, let self, self.aimedEntity === entity else { return }
            await self.populatePreview(container: container, children: children, theme: theme)
        }
    }

    private func populatePreview(container: Entity, children: [FileNode], theme: Theme) async {
        let previewChildren = Array(children.prefix(24))
        guard !previewChildren.isEmpty else { return }

        let cols = gridColumnCount(for: previewChildren.count)
        let rows = Int(ceil(Double(previewChildren.count) / Double(cols)))

        // Scale the mini-grid so its footprint fits within the hovered folder's boxSize × boxSize area,
        // leaving a 12.5% margin on each side.
        let targetSize = boxSize * (1 - 0.125)
        let scaleX = cols > 1 ? targetSize / (Float(cols - 1) * spacing + boxSize) : (1 - 0.125)
        let scaleZ = rows > 1 ? targetSize / (Float(rows - 1) * spacing + boxSize) : (1 - 0.125)
        let scaleFactor = min(scaleX, scaleZ)
        let miniSpacing = spacing * scaleFactor

        for (i, node) in previewChildren.enumerated() {
            guard !Task.isCancelled else { return }
            let mini = await VolumeNode.make(fileNode: node, boxWidth: boxSize, boxDepth: boxSize, theme: theme)
            mini.components.remove(CollisionComponent.self)
            mini.components.remove(InputTargetComponent.self)
            mini.scale = SIMD3<Float>(repeating: scaleFactor)
            let miniHeight = mini.boxHeight * scaleFactor
            let col = i % cols
            let row = i / cols
            mini.position = SIMD3<Float>(Float(col) * miniSpacing, miniHeight / 2, Float(row) * miniSpacing)
            container.addChild(mini)
        }
        guard !Task.isCancelled else { return }

        let offsetX = -Float(min(cols, previewChildren.count) - 1) * miniSpacing / 2
        let offsetZ = -Float(rows - 1) * miniSpacing / 2
        for child in container.children {
            child.position.x += offsetX
            child.position.z += offsetZ
        }

        container.components.set(OpacityComponent(opacity: 0))
        if let fadeIn = try? AnimationResource.makeActionAnimation(
            for: FromToByAction<Float>(to: 1, timing: .linear, isAdditive: false),
            duration: 0.2, bindTarget: .opacity
        ) {
            container.playAnimation(fadeIn)
        }
    }

    private func endPreview(restoring entity: Entity?) {
        previewTask?.cancel()
        previewTask = nil
        if let entity, let comp = entity.components[VolumeNodeComponent.self] {
            var restored = entity.transform
            restored.scale.y = 1
            restored.translation.y = comp.boxHeight / 2
            entity.move(to: restored, relativeTo: entity.parent, duration: 0.18, timingFunction: .easeInOut)
        }
        previewContainer?.removeFromParent()
        previewContainer = nil
    }

    private func volume(alongOrigin origin: SIMD3<Float>, direction: SIMD3<Float>) -> Entity? {
        guard let liveScene = cameraEntity.scene else { return nil }
        let hits = liveScene.raycast(origin: origin, direction: direction, length: 400)
        for hit in hits {
            var e: Entity? = hit.entity
            while let candidate = e {
                if candidate.components[VolumeNodeComponent.self] != nil { return candidate }
                e = candidate.parent
            }
        }
        return nil
    }
    #endif

    // MARK: - Grid

    func loadGrid(_ fileNodes: [FileNode], animated: Bool, theme: Theme) async {
        #if !os(visionOS)
        clearAim()
        #endif
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
