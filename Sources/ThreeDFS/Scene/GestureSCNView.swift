#if !os(macOS)
import SceneKit
import UIKit

/// SCNView subclass for visionOS/iOS input:
///   one-finger drag  → orbit
///   pinch            → zoom
///   tap              → navigate into folder
final class GestureSCNView: SCNView, UIGestureRecognizerDelegate {
    var onVolumeClicked: ((VolumeNode) -> Void)?

    private var lastPanLocation: CGPoint = .zero
    private var lastPinchScale: CGFloat = 1.0

    convenience init() { self.init(frame: .zero) }

    override init(frame: CGRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        setupGestures()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)
    }

    // Allow pan and pinch to operate simultaneously without cancelling each other.
    func gestureRecognizer(_ gr: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    // MARK: - Tap → navigate

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let pt = gesture.location(in: self)
        guard let fss = scene as? FileSystemScene,
              let vol = fss.volumeNode(at: pt, in: self) else { return }
        onVolumeClicked?(vol)
    }

    // MARK: - Pan → orbit

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let fss = scene as? FileSystemScene else { return }
        let loc = gesture.location(in: self)
        switch gesture.state {
        case .began:
            lastPanLocation = loc
        case .changed:
            let dx = Float(loc.x - lastPanLocation.x)
            // UIKit y increases downward; invert so dragging up raises elevation.
            let dy = Float(loc.y - lastPanLocation.y)
            fss.camera.orbit(deltaX: dx, deltaY: -dy)
            fss.camera.apply(to: fss.cameraNode)
            lastPanLocation = loc
        default:
            break
        }
    }

    // MARK: - Pinch → zoom

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let fss = scene as? FileSystemScene else { return }
        switch gesture.state {
        case .began:
            lastPinchScale = gesture.scale
        case .changed:
            let delta = Float(gesture.scale / lastPinchScale - 1.0)
            fss.camera.zoom(by: -delta)   // pinch open = zoom in
            fss.camera.apply(to: fss.cameraNode)
            lastPinchScale = gesture.scale
        default:
            break
        }
    }
}
#endif
