import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var navigator = FileNavigator()
    @State private var showBreadcrumbs = true
    #if os(visionOS)
    @State private var showingThemeEditor = false
    #endif

    var body: some View {
//        Group {
//            if navigator.needsRootSelection {
//                WelcomeView(navigator: navigator)
//            } else {
//
//            }
//        }
        mainView
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
        #if os(visionOS)
        // RealityView must be the direct window content on visionOS — wrapping it in
        // a ZStack or other SwiftUI container misaligns the 3D coordinate space.
        FileScapeSceneView(navigator: navigator)
            .ornament(attachmentAnchor: .scene(.bottom)) {
                VStack(spacing: 0) {
                    if showBreadcrumbs {
                        BreadcrumbBar(navigator: navigator)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    Toolbar(navigator: navigator, showBreadcrumbs: $showBreadcrumbs,
                            openThemeEditor: { showingThemeEditor = true })
                }
                .frame(minWidth: 480)
                .animation(.easeInOut(duration: 0.2), value: showBreadcrumbs)
            }
            .ornament(attachmentAnchor: .scene(.top)) {
                if navigator.currentChildren.isEmpty && !navigator.isLoading {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Demo view")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Tap Choose Root… to visualize your own files.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .sheet(isPresented: $showingThemeEditor) {
                ThemeEditorView()
                    .frame(minWidth: 640, minHeight: 480)
            }
        #else
        VStack(spacing: 0) {
            Toolbar(navigator: navigator, showBreadcrumbs: $showBreadcrumbs)

            if showBreadcrumbs {
                BreadcrumbBar(navigator: navigator)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            sceneContent
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.07))
        .animation(.easeInOut(duration: 0.2), value: showBreadcrumbs)
        #endif
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
        #if os(visionOS)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        #else
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
        #if os(visionOS)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        #else
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        #endif
    }
}

// MARK: - Toolbar

private struct Toolbar: View {
    @ObservedObject var navigator: FileNavigator
    @Binding var showBreadcrumbs: Bool
    var openThemeEditor: (() -> Void)? = nil
    @ObservedObject private var themeManager: ThemeManager = .shared
    @Environment(\.openWindow) private var openWindow
    @State private var showingThemeImporter = false
    @State private var showingImportError = false
    @State private var importError: String = ""

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
                Divider()
                Button("Import Theme…") { showingThemeImporter = true }
                #if !os(visionOS)
                Divider()
                Button("Theme Editor…") { openWindow(id: "theme-editor") }
                #endif
            } label: {
                Image(systemName: "paintpalette")
                    .font(.system(size: 12))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Switch theme")

            #if os(visionOS)
            Button {
                openThemeEditor?()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .help("Theme Editor")
            #endif

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
        #if os(visionOS)
        .background(.regularMaterial, in: .rect)
        #else
        .glassEffect(.regular.interactive(), in: .rect)
        #endif
        .fileImporter(
            isPresented: $showingThemeImporter,
            allowedContentTypes: [.json, .plainText]
        ) { result in
            guard case .success(let url) = result else { return }
            _ = url.startAccessingSecurityScopedResource()
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                try themeManager.adoptImportedTheme(from: url)
            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
        }
        .alert("Could not load theme", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError)
        }
    }
}

#Preview {
    ContentView()
}
