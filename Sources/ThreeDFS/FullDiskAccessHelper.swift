#if os(macOS)
import Foundation
import AppKit

/// Detects and requests macOS Full Disk Access.
///
/// FDA is a user-granted privacy permission (System Settings → Privacy & Security →
/// Full Disk Access) that lets an app read the entire filesystem even inside the sandbox.
/// We detect it by checking if a TCC-protected path is readable, then poll until granted.
@MainActor
final class FullDiskAccessHelper: ObservableObject {
    @Published private(set) var isGranted: Bool = false

    private var pollTask: Task<Void, Never>?

    // A path that is only readable when Full Disk Access has been granted.
    private static let probePath = "/Library/Application Support/com.apple.TCC/TCC.db"

    init() {
        isGranted = Self.check()
    }

    static func check() -> Bool {
        FileManager.default.isReadableFile(atPath: probePath)
    }

    /// Opens System Settings to the Full Disk Access pane and starts polling.
    func requestAccess() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
        startPolling()
    }

    /// Re-checks FDA status — call when the app becomes active again.
    func refresh() {
        let granted = Self.check()
        if granted != isGranted {
            isGranted = granted
        }
    }

    // MARK: - Private

    private func startPolling() {
        guard !isGranted else { return }
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 s
                guard let self else { return }
                let granted = Self.check()
                if granted != self.isGranted {
                    self.isGranted = granted
                }
                if granted {
                    self.pollTask?.cancel()
                    return
                }
            }
        }
    }
}
#endif
