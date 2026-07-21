@preconcurrency import Foundation
@preconcurrency import GameController
import Observation

/// Bridges a connected extended gamepad (Xbox/PlayStation/MFi layout) to the scene.
/// Owned by `FileScapeSceneView`; sampled once per frame by its game-loop timer so
/// stick deflection reads as continuous analog input rather than one-shot deltas.
@MainActor
@Observable
final class GameControllerManager {
    private(set) var isConnected = false

    /// Fired when the primary action button (A / Cross) is pressed.
    @ObservationIgnored var onEnter: (() -> Void)?
    /// Fired when the secondary action button (B / Circle) is pressed.
    @ObservationIgnored var onBack: (() -> Void)?

    struct FrameInput {
        var panX: Float = 0
        var panY: Float = 0
        var orbitX: Float = 0
        var orbitY: Float = 0
        var zoom: Float = 0
    }

    @ObservationIgnored private var gamepad: GCExtendedGamepad?
    // nonisolated(unsafe): written only from init/@MainActor, read only from deinit after actor is done
    @ObservationIgnored nonisolated(unsafe) private var connectObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var disconnectObserver: NSObjectProtocol?
    private let deadzone: Float = 0.12

    init() {
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            // queue: .main guarantees we're on the main thread; no cross-actor send needed
            MainActor.assumeIsolated { self?.attach(controller) }
        }
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            MainActor.assumeIsolated { self?.detach(controller) }
        }
        if let existing = GCController.controllers().first {
            attach(existing)
        }
        GCController.startWirelessControllerDiscovery()
    }

    deinit {
        if let connectObserver { NotificationCenter.default.removeObserver(connectObserver) }
        if let disconnectObserver { NotificationCenter.default.removeObserver(disconnectObserver) }
    }

    /// Reads the current stick/trigger state. Returns `nil` when nothing is connected
    /// or every axis is within the deadzone, so callers can skip camera work cheaply.
    func sampleFrame() -> FrameInput? {
        guard let gamepad else { return nil }

        var input = FrameInput()
        input.panX = applyDeadzone(gamepad.leftThumbstick.xAxis.value)
        input.panY = applyDeadzone(gamepad.leftThumbstick.yAxis.value)
        input.orbitX = applyDeadzone(gamepad.rightThumbstick.xAxis.value)
        input.orbitY = applyDeadzone(gamepad.rightThumbstick.yAxis.value)
        input.zoom = gamepad.leftTrigger.value - gamepad.rightTrigger.value

        guard input.panX != 0 || input.panY != 0 || input.orbitX != 0 || input.orbitY != 0 || input.zoom != 0
        else { return nil }
        return input
    }

    // MARK: - Private

    private func attach(_ controller: GCController) {
        guard gamepad == nil, let extended = controller.extendedGamepad else { return }
        gamepad = extended
        isConnected = true

        extended.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onEnter?() }
        }
        extended.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.onBack?() }
        }
    }

    private func detach(_ controller: GCController) {
        guard controller.extendedGamepad === gamepad else { return }
        gamepad = nil
        isConnected = false
    }

    private func applyDeadzone(_ value: Float) -> Float {
        abs(value) < deadzone ? 0 : value
    }
}
