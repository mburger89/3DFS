import SwiftUI

struct WelcomeView: View {
#if os(macOS)
    @StateObject private var fdaHelper = FullDiskAccessHelper()
#endif
    let navigator: FileNavigator

    var body: some View {
        ZStack {
            // Deep space background — lets Liquid Glass pull from it naturally
            Color(red: 0.03, green: 0.04, blue: 0.07)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // Logo / title
                VStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 68, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.45, green: 0.65, blue: 1.0),
                                         Color(red: 0.2, green: 0.38, blue: 0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("3DFS")
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)

                    Text("A 3D visualization of your file system")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                // Access cards — Liquid Glass panels
                HStack(alignment: .top, spacing: 16) {
#if os(macOS)
                    AccessCard(
                        icon: "lock.open.fill",
                        iconColor: Color(red: 0.35, green: 0.75, blue: 0.45),
                        title: "Full Disk Access",
                        badge: "Recommended",
                        badgeColor: Color(red: 0.35, green: 0.75, blue: 0.45),
                        description: fdaHelper.isGranted
                            ? "Access granted. Starting from your home folder."
                            : "Grant 3DFS read access to your entire file system. Opens System Settings — no data is collected or transmitted.",
                        actionLabel: fdaHelper.isGranted ? "Granted ✓" : "Open System Settings",
                        actionDisabled: fdaHelper.isGranted,
                        actionTint: Color(red: 0.18, green: 0.55, blue: 0.28)
                    ) {
                        fdaHelper.requestAccess()
                    }
#endif

                    AccessCard(
                        icon: "folder.fill",
                        iconColor: Color(red: 0.35, green: 0.55, blue: 0.95),
                        title: "Choose a Folder",
                        badge: nil,
                        badgeColor: .clear,
                        description: "Pick any folder to explore. Your selection is remembered across launches.",
                        actionLabel: "Choose Folder…",
                        actionDisabled: false,
                        actionTint: Color(red: 0.18, green: 0.35, blue: 0.75)
                    ) {
                        navigator.pickFolder()
                    }
                }
                .frame(maxWidth: 680)

                // Controls hint
                VStack(spacing: 8) {
                    Divider().opacity(0.15)
                    HStack(spacing: 28) {
                        hint("Left drag", "Orbit")
                        hint("Two-finger scroll", "Pan")
                        hint("Pinch", "Zoom")
                        hint("Click volume", "Enter folder")
#if os(macOS)
                        hint("WASD · Q/E", "Pan · Zoom")
#endif
                    }
                }
                .padding(.top, 4)
            }
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
#if os(macOS)
        .onReceive(fdaHelper.$isGranted) { granted in
            if granted { navigator.useFullDiskAccess() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            fdaHelper.refresh()
        }
#endif
    }

    private func hint(_ key: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.55, green: 0.72, blue: 1.0))
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - AccessCard

private struct AccessCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let badge: String?
    let badgeColor: Color
    let description: String
    let actionLabel: String
    let actionDisabled: Bool
    let actionTint: Color
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.15))
                        .clipShape(.rect(cornerRadius: 5))
                }
            }

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            Button(action: action) {
                Text(actionLabel)
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .tint(actionDisabled ? Color.secondary.opacity(0.3) : actionTint)
            .disabled(actionDisabled)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
#if os(macOS)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
#else
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
#endif
    }
}
