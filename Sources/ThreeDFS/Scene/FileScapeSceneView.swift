import SwiftUI
import RealityKit

struct FileScapeSceneView: View {
    var navigator: FileNavigator
    var themeManager: ThemeManager = .shared
    @State private var scene = FileSystemSceneManager()
    @State private var gamepad = GameControllerManager()

    // Gesture tracking state
    @State private var lastDragLocation: CGPoint?
    @State private var lastMagnification: CGFloat = 1.0

    #if os(macOS)
    @State private var keysDown: Set<KeyEquivalent> = []
    @State private var lastHoverPoint: CGPoint = .zero
    @FocusState private var isFocused: Bool
    #endif

    var body: some View {
        GeometryReader { proxy in
            ZStack {
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
                .task {
                    while !Task.isCancelled {
                        handleWASD()
                        try? await Task.sleep(for: .seconds(1.0 / 60.0))
                    }
                }
                .onContinuousHover(coordinateSpace: .local) { phase in
                    switch phase {
                    case .active(let location):
                        let dx = location.x - lastHoverPoint.x
                        let dy = location.y - lastHoverPoint.y
                        guard dx * dx + dy * dy > 4 else { return }
                        lastHoverPoint = location
                        scene.updateHoverAim(screenPoint: location, viewSize: proxy.size, index: navigator.index)
                    case .ended:
                        scene.clearAim()
                    }
                }
                #endif

                #if !os(visionOS)
                if gamepad.isConnected {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 2)
                        .allowsHitTesting(false)
                }
                #endif
            }
        }
        .onAppear {
            gamepad.onEnter = {
                #if !os(visionOS)
                guard let node = scene.aimedFileNode, node.isDirectory else { return }
                Task { @MainActor in await navigator.navigateTo(node) }
                #endif
            }
            gamepad.onBack = {
                Task { @MainActor in await navigator.navigateBack() }
            }
        }
        .task {
            while !Task.isCancelled {
                handleGamepad()
                try? await Task.sleep(for: .seconds(1.0 / 60.0))
            }
        }
        #if !os(visionOS)
        .onChange(of: gamepad.isConnected) { _, connected in
            if !connected { scene.clearAim() }
        }
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
        var cameraMoved = false
        if keysDown.contains("w") { panY += speed }
        if keysDown.contains("s") { panY -= speed }
        if keysDown.contains("a") { panX -= speed }
        if keysDown.contains("d") { panX += speed }
        if keysDown.contains("q") { scene.camera.zoom(by: -0.02); cameraMoved = true }
        if keysDown.contains("e") { scene.camera.zoom(by:  0.02); cameraMoved = true }
        if panX != 0 || panY != 0 { scene.camera.pan(deltaX: panX * 12, deltaY: panY * 12); cameraMoved = true }
        if cameraMoved { scene.applyCamera() }
    }
    #endif

    // MARK: - Gamepad (left stick pan, right stick orbit, triggers zoom, A enter / B back)

    private func handleGamepad() {
        var cameraMoved = false
        if let input = gamepad.sampleFrame() {
            if input.panX != 0 || input.panY != 0 {
                scene.camera.pan(deltaX: input.panX * 12, deltaY: input.panY * 12)
                cameraMoved = true
            }
            if input.orbitX != 0 || input.orbitY != 0 {
                scene.camera.orbit(deltaX: input.orbitX * 18, deltaY: input.orbitY * 18)
                cameraMoved = true
            }
            if input.zoom != 0 {
                scene.camera.zoom(by: input.zoom * 0.03)
                cameraMoved = true
            }
            if cameraMoved { scene.applyCamera() }
        }
        #if !os(visionOS)
        if gamepad.isConnected && cameraMoved { scene.updateReticleAim(index: navigator.index) }
        #endif
    }
}

#Preview {
    FileScapeSceneView(navigator: FileNavigator())
}
