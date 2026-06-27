#if os(macOS)
import SceneKit
import AppKit

/// SCNView subclass that owns all input handling:
///   left drag          → orbit  (clamped above ground plane)
///   two-finger scroll  → pan focus point
///   pinch / scroll     → zoom
///   WASD / QE          → pan focus point
final class KeyCaptureSCNView: SCNView {
    var keysDown: Set<UInt16> = []
    var onVolumeClicked: ((VolumeNode) -> Void)?

    // Drag state — used to distinguish click from orbit/pan drag
    private var dragStart: CGPoint = .zero
    private var lastDragLocation: CGPoint = .zero
    private var isDragging = false
    private var isPanDrag = false
    private let dragThreshold: CGFloat = 4

    // Hover
    private var lastHovered: VolumeNode?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
        rebuildTrackingArea()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        rebuildTrackingArea()
    }

    private func rebuildTrackingArea() {
        if let old = trackingArea { removeTrackingArea(old) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) { keysDown.insert(event.keyCode) }
    override func keyUp(with event: NSEvent)   { keysDown.remove(event.keyCode) }

    // MARK: - Mouse: click vs orbit drag

    override func mouseDown(with event: NSEvent) {
        let loc = viewPoint(event)
        dragStart = loc
        lastDragLocation = loc
        isDragging = false
        isPanDrag = event.modifierFlags.contains(.shift)
        window?.makeFirstResponder(self)
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = viewPoint(event)

        if !isDragging {
            let d = hypot(loc.x - dragStart.x, loc.y - dragStart.y)
            if d > dragThreshold { isDragging = true }
        }

        if isDragging, let scene = scene as? FileSystemScene {
            let dx = Float(loc.x - lastDragLocation.x)
            let dy = Float(loc.y - lastDragLocation.y)
            if isPanDrag {
                scene.camera.slide(deltaX: dx, deltaY: dy)
            } else {
                scene.camera.orbit(deltaX: dx, deltaY: dy)
            }
            scene.camera.apply(to: scene.cameraNode)
        }

        lastDragLocation = loc
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            let pt = hitTestPoint(event)
            if let scene = scene as? FileSystemScene,
               let vol = scene.volumeNode(at: pt, in: self) {
                onVolumeClicked?(vol)
            }
        }
        isDragging = false
    }

    // MARK: - Hover

    override func mouseMoved(with event: NSEvent) {
        let pt = hitTestPoint(event)
        guard let scene = scene as? FileSystemScene else { return }
        let hovered = scene.volumeNode(at: pt, in: self)
        if hovered?.fileNode.url != lastHovered?.fileNode.url {
            lastHovered?.setHighlighted(false)
            hovered?.setHighlighted(hovered != nil)
            lastHovered = hovered
            resetCursorRects()
        }
    }

    override func mouseExited(with event: NSEvent) {
        lastHovered?.setHighlighted(false)
        lastHovered = nil
        resetCursorRects()
    }

    override func resetCursorRects() {
        discardCursorRects()
        if lastHovered?.fileNode.isDirectory == true {
            addCursorRect(bounds, cursor: .pointingHand)
        }
    }

    // MARK: - Scroll: pan (two-finger) or zoom (mouse wheel)

    override func scrollWheel(with event: NSEvent) {
        guard let scene = scene as? FileSystemScene else { return }

        let isTrackpad = event.phase != [] || event.momentumPhase != []
        if isTrackpad {
            scene.camera.pan(
                deltaX: Float(event.scrollingDeltaX),
                deltaY: Float(event.scrollingDeltaY)
            )
        } else {
            scene.camera.zoom(by: Float(-event.deltaY) * 0.04)
        }
        scene.camera.apply(to: scene.cameraNode)
    }

    // MARK: - Pinch: zoom

    override func magnify(with event: NSEvent) {
        guard let scene = scene as? FileSystemScene else { return }
        scene.camera.zoom(by: Float(-event.magnification))
        scene.camera.apply(to: scene.cameraNode)
    }

    // MARK: - Helpers

    private func viewPoint(_ event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }

    private func hitTestPoint(_ event: NSEvent) -> CGPoint {
        let loc = viewPoint(event)
        return CGPoint(x: loc.x, y: bounds.height - loc.y)
    }
}
#endif
