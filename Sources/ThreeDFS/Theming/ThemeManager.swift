import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var current: Theme = .default_ {
        didSet { saveSelection() }
    }

    @Published private(set) var customThemes: [Theme] = []

    var allThemes: [Theme] { Theme.builtIn + customThemes }

    // MARK: - Save / delete / export (editor-driven)

    func saveCustomTheme(_ theme: Theme) {
        let dir = customThemesDirectory()
        let filename = theme.name.replacingOccurrences(of: "/", with: "-") + ".json"
        let url = dir.appendingPathComponent(filename)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(theme) else { return }
        try? data.write(to: url)
        if let idx = customThemes.firstIndex(where: { $0.name == theme.name }) {
            customThemes[idx] = theme
        } else {
            customThemes.append(theme)
        }
        if current.name == theme.name {
            current = theme
        }
    }

    func updateCustomTheme(_ theme: Theme) {
        saveCustomTheme(theme)
    }

    func deleteCustomTheme(_ theme: Theme) {
        let dir = customThemesDirectory()
        let filename = theme.name.replacingOccurrences(of: "/", with: "-") + ".json"
        let url = dir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
        customThemes.removeAll { $0.name == theme.name }
        if current.name == theme.name {
            current = allThemes.first ?? .default_
        }
    }

#if os(macOS)
    func exportTheme(_ theme: Theme) {
        let alert = NSAlert()
        alert.messageText = "Export \"\(theme.name)\""
        alert.informativeText = "Choose a file format."
        alert.addButton(withTitle: "JSON")
        alert.addButton(withTitle: "YAML")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        guard response != .alertThirdButtonReturn else { return }
        let useYAML = response == .alertSecondButtonReturn

        let panel = NSSavePanel()
        panel.title = "Export Theme"
        panel.nameFieldStringValue = theme.name + (useYAML ? ".yaml" : ".json")
        panel.allowedContentTypes = useYAML ? [] : [.json]
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if useYAML {
            let yaml = themeToYAML(theme)
            try? yaml.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(theme) else { return }
            try? data.write(to: url)
        }
    }

    private func themeToYAML(_ theme: Theme) -> String {
        func kv(_ key: String, _ val: String, indent: Int = 2) -> String {
            String(repeating: " ", count: indent) + "\(key): \"\(val)\""
        }
        var lines: [String] = []
        lines.append("name: \"\(theme.name)\"")
        lines.append("")
        lines.append("scene:")
        lines.append(kv("background", theme.scene.background))
        lines.append(kv("bottomFace", theme.scene.bottomFace))
        lines.append("")
        lines.append("directory:")
        lines.append(kv("sideBackground", theme.directory.sideBackground))
        lines.append(kv("sideBorder",     theme.directory.sideBorder))
        lines.append(kv("nameText",       theme.directory.nameText))
        lines.append(kv("subtitleText",   theme.directory.subtitleText))
        lines.append(kv("childText",      theme.directory.childText))
        lines.append(kv("moreText",       theme.directory.moreText))
        lines.append(kv("topColor",       theme.directory.topColor))
        lines.append(kv("topEmission",    theme.directory.topEmission))
        lines.append("")
        lines.append("file:")
        lines.append(kv("sideColor",       theme.file.sideColor))
        lines.append(kv("topBackground",   theme.file.topBackground))
        lines.append(kv("topBorder",       theme.file.topBorder))
        lines.append(kv("badgeText",       theme.file.badgeText))
        lines.append(kv("badgeBackground", theme.file.badgeBackground))
        lines.append(kv("nameText",        theme.file.nameText))
        lines.append(kv("typeText",        theme.file.typeText))
        lines.append(kv("sizeText",        theme.file.sizeText))
        lines.append(kv("dateText",        theme.file.dateText))
        lines.append("")
        return lines.joined(separator: "\n")
    }
#endif

    private let selectionKey = "com.maxburger.threedfs.themeID"

    private init() {
        loadCustomThemes()
        restoreSelection()
    }

    // MARK: - Load / import

#if os(macOS)
    /// Import a theme from a .json or .yaml/.yml file chosen by the user.
    func importTheme() {
        let panel = NSOpenPanel()
        panel.title = "Import Theme"
        panel.message = "Choose a .json or .yaml theme file"
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.prompt = "Import"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let theme = try loadTheme(from: url)
            // Copy to Application Support so it persists
            let dest = customThemesDirectory().appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
            if !customThemes.contains(where: { $0.name == theme.name }) {
                customThemes.append(theme)
            }
            current = theme
        } catch {
            // Surface error via alert
            let alert = NSAlert()
            alert.messageText = "Could not load theme"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
#endif

    // MARK: - Private

    private func loadTheme(from url: URL) throws -> Theme {
        let ext = url.pathExtension.lowercased()
        let data: Data
        if ext == "yaml" || ext == "yml" {
            let text = try String(contentsOf: url, encoding: .utf8)
            data = try YAMLThemeParser.toJSON(text)
        } else {
            data = try Data(contentsOf: url)
        }
        return try JSONDecoder().decode(Theme.self, from: data)
    }

    private func loadCustomThemes() {
        let dir = customThemesDirectory()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil
        ) else { return }
        for url in files where ["json","yaml","yml"].contains(url.pathExtension.lowercased()) {
            if let theme = try? loadTheme(from: url),
               !customThemes.contains(where: { $0.name == theme.name }) {
                customThemes.append(theme)
            }
        }
    }

    private func customThemesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("3DFS/Themes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func saveSelection() {
        UserDefaults.standard.set(current.name, forKey: selectionKey)
    }

    private func restoreSelection() {
        guard let name = UserDefaults.standard.string(forKey: selectionKey),
              let theme = allThemes.first(where: { $0.name == name }) else { return }
        current = theme
    }
}
