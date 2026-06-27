import SceneKit
import CoreGraphics

@MainActor
final class FileSystemScene: SCNScene {
    private(set) var cameraNode: SCNNode!
    let camera = CameraController()
    private var gridContainerNode: SCNNode?

    private let spacing: Float = 2.6
    private let boxSize: Float  = 1.9

    override init() {
        super.init()
        MainActor.assumeIsolated {
            setupEnvironment()
            setupCamera()
            setupLights()
            setupFloor()
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupEnvironment() {
        applyTheme(ThemeManager.shared.current)
    }

    func applyTheme(_ theme: Theme) {
        background.contents = CGColor.from(hex: theme.scene.background)
            ?? CGColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: 1)
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.fieldOfView = 60
        cam.zNear = 0.1
        cam.zFar = 500

        cameraNode = SCNNode()
        cameraNode.camera = cam
        camera.apply(to: cameraNode)
        rootNode.addChildNode(cameraNode)
    }

    private func setupLights() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = CGColor(gray: 0.28, alpha: 1)
        let ambientNode = SCNNode(); ambientNode.light = ambient
        rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.color = CGColor(srgbRed: 0.9, green: 0.92, blue: 1.0, alpha: 1)
        key.intensity = 800
        key.castsShadow = true
        key.shadowRadius = 4
        key.shadowColor = CGColor(gray: 0, alpha: 0.5)
        key.shadowMode = .deferred
        let keyNode = SCNNode(); keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.color = CGColor(srgbRed: 0.3, green: 0.4, blue: 0.7, alpha: 1)
        fill.intensity = 300
        let fillNode = SCNNode(); fillNode.light = fill
        fillNode.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)
        rootNode.addChildNode(fillNode)
    }

    private func setupFloor() {
        let floor = SCNFloor()
        floor.reflectivity = 0.08
        floor.reflectionFalloffEnd = 8
        let mat = SCNMaterial()
        mat.diffuse.contents = CGColor(srgbRed: 0.05, green: 0.06, blue: 0.10, alpha: 1)
        mat.lightingModel = .lambert
        floor.materials = [mat]
        rootNode.addChildNode(SCNNode(geometry: floor))
    }

    // MARK: - Grid

    func loadGrid(_ fileNodes: [FileNode], animated: Bool, theme: Theme? = nil, completion: (() -> Void)? = nil) {
        let theme = theme ?? ThemeManager.shared.current
        applyTheme(theme)
        let old = gridContainerNode
        let newContainer = buildGridNode(fileNodes: fileNodes, theme: theme)
        newContainer.opacity = 0
        rootNode.addChildNode(newContainer)
        gridContainerNode = newContainer

        let cols = gridColumnCount(for: fileNodes.count)
        let rows = fileNodes.isEmpty ? 0 : Int(ceil(Double(fileNodes.count) / Double(cols)))
        camera.resetForGrid(cols: cols, rows: rows, spacing: spacing)

        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.22 : 0
        old?.opacity = 0
        camera.apply(to: cameraNode)
        SCNTransaction.completionBlock = {
            old?.removeFromParentNode()
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.28 : 0
            newContainer.opacity = 1
            SCNTransaction.completionBlock = { completion?() }
            SCNTransaction.commit()
        }
        SCNTransaction.commit()
    }

    private func buildGridNode(fileNodes: [FileNode], theme: Theme) -> SCNNode {
        let container = SCNNode()
        let cols = gridColumnCount(for: fileNodes.count)

        for (i, node) in fileNodes.enumerated() {
            let col = i % cols
            let row = i / cols
            let volume = VolumeNode(fileNode: node, boxWidth: boxSize, boxDepth: boxSize, theme: theme)
            volume.position = SCNVector3(Float(col) * spacing, volume.boxHeight / 2, Float(row) * spacing)
            container.addChildNode(volume)
        }

        let totalCols = min(cols, fileNodes.count)
        let totalRows = fileNodes.isEmpty ? 0 : Int(ceil(Double(fileNodes.count) / Double(cols)))
        container.position = SCNVector3(
            -Float(totalCols - 1) * spacing / 2,
            0,
            -Float(totalRows - 1) * spacing / 2
        )
        return container
    }

    private func gridColumnCount(for count: Int) -> Int {
        max(1, Int(ceil(sqrt(Double(count)))))
    }

    // MARK: - Hit Testing

    func volumeNode(at point: CGPoint, in view: SCNView) -> VolumeNode? {
        let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue])
        for hit in hits {
            var node: SCNNode? = hit.node
            while let n = node {
                if let vol = n as? VolumeNode { return vol }
                node = n.parent
            }
        }
        return nil
    }
}
