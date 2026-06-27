import SwiftUI
import SceneKit
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct FileScapeSceneView {
    @ObservedObject var navigator: FileNavigator
    @ObservedObject var themeManager: ThemeManager = .shared

    func makeCoordinator() -> Coordinator { Coordinator(navigator: navigator) }

    // MARK: - Coordinator (shared across platforms)

    @MainActor
    final class Coordinator: NSObject, @preconcurrency SCNSceneRendererDelegate {
        let navigator: FileNavigator
        var loadedEpoch: UUID? = nil
        var loadedTheme: Theme? = nil
        weak var scnView: SCNView?          // typed as superclass; platform-specific subclass assigned at make time

        #if os(macOS)
        private let moveSpeed: Float = 0.08
        #endif

        init(navigator: FileNavigator) { self.navigator = navigator }

        func loadScene(children: [FileNode], animated: Bool) {
            guard let scene = scnView?.scene as? FileSystemScene else { return }
            scene.loadGrid(children, animated: animated, theme: ThemeManager.shared.current)
        }

        func handleClick(_ volume: VolumeNode) {
            guard volume.fileNode.isDirectory else { return }
            Task { @MainActor in await navigator.navigateTo(volume.fileNode) }
        }

        // Per-frame WASD camera movement — macOS keyboard only.
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
#if os(macOS)
            guard let kv = scnView as? KeyCaptureSCNView,
                  let scene = kv.scene as? FileSystemScene else { return }
            let keys = kv.keysDown
            guard !keys.isEmpty else { return }

            // Key codes: W=13, S=1, A=0, D=2, Q=12, E=14
            var panX: Float = 0, panY: Float = 0
            if keys.contains(13) { panY += moveSpeed }
            if keys.contains(1)  { panY -= moveSpeed }
            if keys.contains(0)  { panX -= moveSpeed }
            if keys.contains(2)  { panX += moveSpeed }
            if keys.contains(12) { scene.camera.zoom(by: -0.02) }
            if keys.contains(14) { scene.camera.zoom(by:  0.02) }

            if panX != 0 || panY != 0 { scene.camera.pan(deltaX: panX * 12, deltaY: panY * 12) }
            scene.camera.apply(to: scene.cameraNode)
#endif
        }
    }
}

// MARK: - macOS: NSViewRepresentable

#if os(macOS)
extension FileScapeSceneView: NSViewRepresentable {
    func makeNSView(context: Context) -> KeyCaptureSCNView {
        let scnView = KeyCaptureSCNView()
        scnView.scene = FileSystemScene()
        scnView.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        configure(scnView, context: context)
        return scnView
    }

    func updateNSView(_ nsView: KeyCaptureSCNView, context: Context) {
        applyUpdate(to: context.coordinator)
    }
}

// MARK: - visionOS / iOS: UIViewRepresentable

#else
extension FileScapeSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> GestureSCNView {
        let scnView = GestureSCNView()
        scnView.scene = FileSystemScene()
        scnView.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        configure(scnView, context: context)
        return scnView
    }

    func updateUIView(_ uiView: GestureSCNView, context: Context) {
        applyUpdate(to: context.coordinator)
    }
}
#endif

// MARK: - Shared setup / update helpers

private extension FileScapeSceneView {
    func configure(_ scnView: SCNView, context: Context) {
        scnView.antialiasingMode = .multisampling4X
        scnView.showsStatistics = false
        scnView.allowsCameraControl = false
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.delegate = context.coordinator
        context.coordinator.scnView = scnView

        let onClicked: (VolumeNode) -> Void = { [weak coordinator = context.coordinator] volume in
            coordinator?.handleClick(volume)
        }
        #if os(macOS)
        (scnView as? KeyCaptureSCNView)?.onVolumeClicked = onClicked
        #else
        (scnView as? GestureSCNView)?.onVolumeClicked = onClicked
        #endif
    }

    func applyUpdate(to coordinator: Coordinator) {
        let themeChanged = coordinator.loadedTheme != themeManager.current
        guard coordinator.loadedEpoch != navigator.epoch || themeChanged else { return }
        let isFirstLoad = coordinator.loadedEpoch == nil
        coordinator.loadedEpoch = navigator.epoch
        coordinator.loadedTheme = themeManager.current
        coordinator.loadScene(children: navigator.currentChildren, animated: !isFirstLoad && !themeChanged)
    }
}
