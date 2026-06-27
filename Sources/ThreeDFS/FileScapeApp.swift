import SwiftUI

@main
struct ThreeDFSApp: App {
    var body: some Scene {
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

        Window("Theme Editor", id: "theme-editor") {
            ThemeEditorView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 720, height: 560)
    }
}
