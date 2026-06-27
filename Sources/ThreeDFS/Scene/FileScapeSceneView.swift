import SwiftUI
import SceneKit

struct FileScapeSceneView: NSViewRepresentable {
    @ObservedObject var navigator: FileNavigator
    @ObservedObject var themeManager: ThemeManager = .shared

    func makeCoordinator() -> Coordinator {
        Coordinator(navigator: navigator)
    }

    func makeNSView(context: Context) -> KeyCaptureSCNView {
        let scnView = KeyCaptureSCNView()
        let scene = FileSystemScene()
        scnView.scene = scene
        scnView.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.showsStatistics = false
        scnView.allowsCameraControl = false
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60

        let delegate = context.coordinator
        scnView.delegate = delegate
        context.coordinator.scnView = scnView

        scnView.onVolumeClicked = { [weak coordinator = context.coordinator] volume in
            coordinator?.handleClick(volume)
        }

        return scnView
    }

    func updateNSView(_ nsView: KeyCaptureSCNView, context: Context) {
        let coord = context.coordinator
        let themeChanged = coord.loadedTheme != themeManager.current
        guard coord.loadedEpoch != navigator.epoch || themeChanged else { return }
        let isFirstLoad = coord.loadedEpoch == nil
        coord.loadedEpoch = navigator.epoch
        coord.loadedTheme = themeManager.current
        coord.loadScene(children: navigator.currentChildren, animated: !isFirstLoad && !themeChanged)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, @preconcurrency SCNSceneRendererDelegate {
        let navigator: FileNavigator
        weak var scnView: KeyCaptureSCNView?
        var loadedEpoch: UUID? = nil
        var loadedTheme: Theme? = nil

        // Key codes: W=13, S=1, A=0, D=2
        private let moveSpeed: Float = 0.08

        init(navigator: FileNavigator) {
            self.navigator = navigator
        }

        func loadScene(children: [FileNode], animated: Bool) {
            guard let scene = scnView?.scene as? FileSystemScene else { return }
            scene.loadGrid(children, animated: animated, theme: ThemeManager.shared.current)
        }

        func handleClick(_ volume: VolumeNode) {
            guard volume.fileNode.isDirectory else { return }
            Task { @MainActor in
                await navigator.navigateTo(volume.fileNode)
            }
        }

        // MARK: - Per-frame WASD: pan the camera's focus point

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let scnView, let scene = scnView.scene as? FileSystemScene else { return }
            let keys = scnView.keysDown
            guard !keys.isEmpty else { return }

            // Key codes: W=13, S=1, A=0, D=2, Q=12, E=14
            var panX: Float = 0
            var panY: Float = 0

            if keys.contains(13) { panY += moveSpeed }   // W — pan forward
            if keys.contains(1)  { panY -= moveSpeed }   // S — pan back
            if keys.contains(0)  { panX -= moveSpeed }   // A — pan left
            if keys.contains(2)  { panX += moveSpeed }   // D — pan right
            if keys.contains(12) { scene.camera.zoom(by: -0.02) }   // Q — zoom in
            if keys.contains(14) { scene.camera.zoom(by:  0.02) }   // E — zoom out

            if panX != 0 || panY != 0 {
                scene.camera.pan(deltaX: panX * 12, deltaY: panY * 12)
            }
            scene.camera.apply(to: scene.cameraNode)
        }
    }
}
