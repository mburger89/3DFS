import SwiftUI
import RealityKit
import Combine

struct FileScapeSceneView: View {
    @ObservedObject var navigator: FileNavigator
    @ObservedObject var themeManager: ThemeManager = .shared
    @StateObject private var scene = FileSystemSceneManager()

    // Gesture tracking state
    @State private var lastDragLocation: CGPoint?
    @State private var lastMagnification: CGFloat = 1.0

    #if os(macOS)
    @State private var keysDown: Set<KeyEquivalent> = []
    @FocusState private var isFocused: Bool
    private let wasdTimer = Timer.publish(every: 1 / 60.0, on: .main, in: .common).autoconnect()
    #endif

    var body: some View {
        RealityView { [scene] content in
            scene.setup()
            content.add(scene.rootEntity)
            #if !os(visionOS)
            content.add(scene.cameraEntity)
            #endif
        }
        .task(id: "\(navigator.epoch)|\(themeManager.current.name)") {
            await scene.loadGrid(
                navigator.currentChildren,
                animated: scene.gridLoadCount > 0,
                theme: themeManager.current
            )
        }
        .gesture(dragGesture)
        .simultaneousGesture(magnifyGesture)
        .simultaneousGesture(tapGesture)
        #if os(macOS)
        .focusable()
        .focused($isFocused)
        .onAppear { isFocused = true }
        .onKeyPress(phases: [.down, .up]) { press in
            if press.phase == .down { keysDown.insert(press.key) }
            else                    { keysDown.remove(press.key) }
            return .handled
        }
        .onReceive(wasdTimer) { _ in handleWASD() }
        #endif
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if let last = lastDragLocation {
                    let dx = Float(value.location.x - last.x)
                    let dy = Float(value.location.y - last.y)
                    // UIKit / SwiftUI y-axis grows downward: invert Y so dragging up raises elevation
                    scene.camera.orbit(deltaX: dx, deltaY: -dy)
                    scene.applyCamera()
                }
                lastDragLocation = value.location
            }
            .onEnded { _ in lastDragLocation = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let delta = Float(value.magnification / lastMagnification - 1.0)
                scene.camera.zoom(by: -delta)   // pinch open → zoom in
                scene.applyCamera()
                lastMagnification = value.magnification
            }
            .onEnded { _ in lastMagnification = 1.0 }
    }

    private var tapGesture: some Gesture {
        TapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                // Walk hierarchy to find VolumeNodeComponent
                var entity: Entity? = value.entity
                while let e = entity {
                    if let comp = e.components[VolumeNodeComponent.self] {
                        guard comp.fileNode.isDirectory else { return }
                        Task { @MainActor in await navigator.navigateTo(comp.fileNode) }
                        return
                    }
                    entity = e.parent
                }
            }
    }

    // MARK: - macOS keyboard (WASD / Q / E)

    #if os(macOS)
    private func handleWASD() {
        guard !keysDown.isEmpty else { return }
        let speed: Float = 0.08
        var panX: Float = 0, panY: Float = 0
        if keysDown.contains("w") { panY += speed }
        if keysDown.contains("s") { panY -= speed }
        if keysDown.contains("a") { panX -= speed }
        if keysDown.contains("d") { panX += speed }
        if keysDown.contains("q") { scene.camera.zoom(by: -0.02) }
        if keysDown.contains("e") { scene.camera.zoom(by:  0.02) }
        if panX != 0 || panY != 0 { scene.camera.pan(deltaX: panX * 12, deltaY: panY * 12) }
        scene.applyCamera()
    }
    #endif
}

#Preview {
    FileScapeSceneView(navigator: FileNavigator())
}
