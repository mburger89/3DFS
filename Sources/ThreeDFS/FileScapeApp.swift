import SwiftUI

@main
struct ThreeDFSApp: App {
    var body: some Scene {
        mainWindowScene
        themeEditorScene
    }
}

#if os(macOS)
private extension ThreeDFSApp {
    var mainWindowScene: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About 3DFS") { }
            }
        }
    }

    var themeEditorScene: some Scene {
        Window("Theme Editor", id: "theme-editor") {
            ThemeEditorView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 720, height: 560)
    }
}
#else
private extension ThreeDFSApp {
    var mainWindowScene: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 1.2, height: 0.8, depth: 1.2, in: .meters)
    }

    // Declared so visionOS can match any cached UIWindowSceneSessionRoleApplication
    // session from a previous build. The scene is fully suppressed — the Theme Editor
    // is presented as a sheet from ContentView instead.
    var themeEditorScene: some Scene {
        Window("Theme Editor", id: "theme-editor") {
            EmptyView()
        }
        .restorationBehavior(.disabled)
    }
}
#endif
