import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var navigator = FileNavigator()
    @State private var showBreadcrumbs = true

    var body: some View {
        Group {
            if navigator.needsRootSelection {
                WelcomeView(navigator: navigator)
            } else {
                mainView
            }
        }
        .fileImporter(
            isPresented: $navigator.showingFolderPicker,
            allowedContentTypes: [.folder]
        ) { result in
            if case .success(let url) = result {
                navigator.adoptRoot(url)
            }
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            Toolbar(navigator: navigator, showBreadcrumbs: $showBreadcrumbs)

            if showBreadcrumbs {
                BreadcrumbBar(navigator: navigator)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                FileScapeSceneView(navigator: navigator)

                if navigator.currentChildren.isEmpty && !navigator.isLoading {
                    emptyState
                }

                if navigator.isLoading {
                    loadingOverlay
                }
            }
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
        .animation(.easeInOut(duration: 0.2), value: showBreadcrumbs)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No accessible items")
                .foregroundStyle(.secondary)
        }
        .padding(24)
#if os(macOS)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
#else
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
#endif
    }

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(.white)
            Text("Scanning…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 110, height: 80)
#if os(macOS)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
#else
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
#endif
    }
}

// MARK: - Toolbar

private struct Toolbar: View {
    @ObservedObject var navigator: FileNavigator
    @Binding var showBreadcrumbs: Bool
    @ObservedObject private var themeManager: ThemeManager = .shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 8) {
            Button {
                Task { await navigator.navigateBack() }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(navigator.canGoBack ? Color.primary : Color.secondary.opacity(0.4))
            .disabled(!navigator.canGoBack)
            .keyboardShortcut("[", modifiers: .command)
            .help("Go back  ⌘[")

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            HStack(spacing: 4) {
                Text("3DFS")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary.opacity(0.6))
                if navigator.path.count > 1 {
                    Text("/ \(navigator.path.last?.name ?? "")")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                showBreadcrumbs.toggle()
            } label: {
                Image(systemName: "text.alignleft")
                    .symbolVariant(showBreadcrumbs ? .fill : .none)
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showBreadcrumbs ? Color.primary : Color.primary.opacity(0.4))
            .help(showBreadcrumbs ? "Hide breadcrumbs" : "Show breadcrumbs")

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            // Theme picker
            Menu {
                ForEach(themeManager.allThemes) { theme in
                    Button {
                        themeManager.current = theme
                    } label: {
                        HStack {
                            Text(theme.name)
                            if theme.name == themeManager.current.name {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
#if os(macOS)
                Divider()
                Button("Import Theme…") { themeManager.importTheme() }
                Button("Theme Editor…") { openWindow(id: "theme-editor") }
#endif
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Switch theme")

            Divider()
                .frame(height: 16)
                .opacity(0.3)

            Button("Choose Root…") {
                navigator.pickFolder()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if navigator.isLoading {
                ProgressView()
                    .scaleEffect(0.55)
                    .frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
#if os(macOS)
        .glassEffect(.regular.interactive(), in: .rect)
#else
        .background(.ultraThinMaterial)
#endif
    }
}
