import RealityKit
import simd

/// Manages camera position in spherical coordinates around a focus point.
/// Elevation is clamped so the camera never goes below the ground plane.
@MainActor
final class CameraController {
    var azimuth: Float = 0
    var elevation: Float = 0.50
    var distance: Float = 14
    var focusPoint = SIMD3<Float>(0, 0, 0)

    private let minElevation: Float = 0.06
    private let maxElevation: Float = 1.52
    private let minDistance:  Float = 2
    private let maxDistance:  Float = 120

    // MARK: - Inputs

    func orbit(deltaX: Float, deltaY: Float) {
        azimuth   -= deltaX * 0.006
        elevation  = clamp(elevation + deltaY * 0.006, minElevation, maxElevation)
    }

    func pan(deltaX: Float, deltaY: Float) {
        let right   = SIMD3<Float>(cos(azimuth), 0, -sin(azimuth))
        let forward = SIMD3<Float>(-sin(azimuth), 0, -cos(azimuth))
        let scale = distance * 0.0012
        focusPoint -= right   * deltaX * scale
        focusPoint += forward * deltaY * scale
    }

    func zoom(by factor: Float) {
        distance = clamp(distance * (1 + factor), minDistance, maxDistance)
    }

    // MARK: - Apply

    /// Moves and orients a perspective camera entity (macOS/iOS).
    func apply(to cameraEntity: Entity) {
        let x = focusPoint.x + distance * cos(elevation) * sin(azimuth)
        let y = max(0.4, distance * sin(elevation))
        let z = focusPoint.z + distance * cos(elevation) * cos(azimuth)
        cameraEntity.look(at: focusPoint, from: SIMD3<Float>(x, y, z), relativeTo: nil)
    }

    /// Rotates and positions the world entity to simulate orbiting.
    /// Used on visionOS where the user's head IS the camera.
    func applyToWorld(_ worldEntity: Entity) {
        let yRot = simd_quatf(angle: -azimuth,                  axis: [0, 1, 0])
        let xRot = simd_quatf(angle:  elevation - Float.pi / 2, axis: [1, 0, 0])
        worldEntity.orientation = yRot * xRot
        worldEntity.position    = SIMD3<Float>(-focusPoint.x, -focusPoint.y, -(distance + focusPoint.z))
    }

    func resetForGrid(cols: Int, rows: Int, spacing: Float) {
        let gridW = Float(max(0, cols - 1)) * spacing
        let gridD = Float(max(0, rows - 1)) * spacing
        focusPoint = SIMD3<Float>(0, 0, 0)
        distance   = max(gridW, gridD) * 0.65 + 9
        elevation  = 0.50
    }

    private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float { min(max(v, lo), hi) }
}
