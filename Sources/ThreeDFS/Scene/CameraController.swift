import SceneKit
import simd

/// Manages camera position in spherical coordinates around a focus point.
/// Elevation is clamped so the camera never goes below the ground plane.
final class CameraController {
    // Spherical coordinates
    var azimuth: Float = 0          // radians, rotation around Y axis
    var elevation: Float = 0.50     // radians above horizon
    var distance: Float = 14

    var focusPoint = SIMD3<Float>(0, 0, 0)

    // Constraints
    private let minElevation: Float = 0.06   // ~3.5° — keeps camera well above ground
    private let maxElevation: Float = 1.52   // ~87° — near straight down
    private let minDistance: Float = 2
    private let maxDistance: Float = 120

    // MARK: - Inputs

    func orbit(deltaX: Float, deltaY: Float) {
        azimuth  -= deltaX * 0.006
        elevation = clamp(elevation + deltaY * 0.006, minElevation, maxElevation)
    }

    /// Pan the focus point in the camera's local XZ plane (no vertical drift).
    func pan(deltaX: Float, deltaY: Float) {
        let right = SIMD3<Float>(cos(azimuth), 0, -sin(azimuth))
        let forward = SIMD3<Float>(-sin(azimuth), 0, -cos(azimuth))

        let scale = distance * 0.0012
        focusPoint -= right   * deltaX * scale
        focusPoint += forward * deltaY * scale
    }

    /// Slide the focus point in screen space: left/right along camera's right vector,
    /// up/down along world Y. No depth (forward) movement — the view plane stays fixed.
    func slide(deltaX: Float, deltaY: Float) {
        let right = SIMD3<Float>(cos(azimuth), 0, -sin(azimuth))
        let up    = SIMD3<Float>(0, 1, 0)

        let scale = distance * 0.0012
        focusPoint -= right * deltaX * scale
        focusPoint += up    * deltaY * scale
    }

    func zoom(by factor: Float) {
        distance = clamp(distance * (1 + factor), minDistance, maxDistance)
    }

    // MARK: - Apply

    func apply(to cameraNode: SCNNode) {
        let x = focusPoint.x + distance * cos(elevation) * sin(azimuth)
        let y = max(0.4, distance * sin(elevation))          // never below ground
        let z = focusPoint.z + distance * cos(elevation) * cos(azimuth)

        cameraNode.simdPosition = SIMD3<Float>(x, y, z)
        cameraNode.simdLook(at: focusPoint, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
    }

    /// Smoothly reposition for a new grid with `cols × rows` items at `spacing` apart.
    func resetForGrid(cols: Int, rows: Int, spacing: Float) {
        let gridW = Float(max(0, cols - 1)) * spacing
        let gridD = Float(max(0, rows - 1)) * spacing
        focusPoint = SIMD3<Float>(0, 0, 0)
        distance = max(gridW, gridD) * 0.65 + 9
        elevation = 0.50
        // azimuth unchanged so orientation feels stable between navigations
    }

    // MARK: - Helpers

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        min(max(v, lo), hi)
    }
}
