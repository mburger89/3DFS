#if os(macOS)
import SwiftUI
import AppKit

// MARK: - Color ↔ Hex helpers

extension Color {
    init(hex: String) {
        if let ns = NSColor(hex: hex) {
            self.init(nsColor: ns)
        } else {
            self.init(white: 1)
        }
    }

    func toHex() -> String {
        guard let ns = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int((ns.redComponent   * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent  * 255).rounded())
        let a = Int((ns.alphaComponent * 255).rounded())
        if a >= 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        } else {
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
    }
}

// MARK: - Theme Editor (standalone window)

struct ThemeEditorView: View {
    @ObservedObject private var manager: ThemeManager = .shared
    @State private var selectedName: String = ThemeManager.shared.current.name
    @State private var showingNewThemeAlert = false
    @State private var newThemeName = ""

    private var isBuiltIn: Bool {
        Theme.builtIn.contains { $0.name == selectedName }
    }

    private var selectedIndex: Int? {
        manager.customThemes.firstIndex { $0.name == selectedName }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            editorPanel
        }
        .onChange(of: selectedName) { _, name in
            if let theme = manager.allThemes.first(where: { $0.name == name }) {
                manager.current = theme
            }
        }
        .alert("New Theme Name", isPresented: $showingNewThemeAlert) {
            TextField("Name", text: $newThemeName)
            Button("Create") { createNewTheme() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selectedName) {
                Section("Built-in") {
                    ForEach(Theme.builtIn) { theme in
                        themeRow(theme, isCustom: false)
                    }
                }
                if !manager.customThemes.isEmpty {
                    Section("Custom") {
                        ForEach(manager.customThemes) { theme in
                            themeRow(theme, isCustom: true)
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 0) {
                Button {
                    newThemeName = ""
                    showingNewThemeAlert = true
                } label: {
                    Image(systemName: "plus").frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("New theme")

                Button { duplicateCurrent() } label: {
                    Image(systemName: "doc.on.doc").frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Duplicate current theme")

                Spacer()

                Button(role: .destructive) { deleteSelected() } label: {
                    Image(systemName: "trash").frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundColor(isBuiltIn ? .secondary.opacity(0.3) : .red.opacity(0.8))
                .disabled(isBuiltIn)
                .help(isBuiltIn ? "Built-in themes cannot be deleted" : "Delete theme")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(width: 180)
    }

    private func themeRow(_ theme: Theme, isCustom: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: theme.directory.topColor))
                .frame(width: 10, height: 10)
            Text(theme.name)
                .font(.system(size: 13))
            Spacer()
        }
        .tag(theme.name)
        .contextMenu {
            Button("Duplicate") { duplicateTheme(theme) }
            if isCustom {
                Button("Export…") { manager.exportTheme(theme) }
                Divider()
                Button("Delete", role: .destructive) {
                    manager.deleteCustomTheme(theme)
                    selectedName = manager.allThemes.first?.name ?? Theme.default_.name
                }
            }
        }
    }

    // MARK: - Editor panel

    private var editorPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if isBuiltIn {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedName)
                            .font(.system(size: 15, weight: .semibold))
                        Text("Built-in — duplicate to edit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Duplicate to Edit") { duplicateCurrent() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    if let theme = manager.customThemes.first(where: { $0.name == selectedName }) {
                        NameField(theme: theme, manager: manager, selectedName: $selectedName)
                    }
                    Spacer()
                    Button("Export…") {
                        if let t = manager.customThemes.first(where: { $0.name == selectedName }) {
                            manager.exportTheme(t)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    colorSection("Scene") {
                        colorRow("Background",  kp: \.scene.background)
                        colorRow("Bottom face", kp: \.scene.bottomFace)
                    }
                    colorSection("Directories") {
                        colorRow("Side background", kp: \.directory.sideBackground)
                        colorRow("Side border",     kp: \.directory.sideBorder)
                        colorRow("Name text",       kp: \.directory.nameText)
                        colorRow("Subtitle text",   kp: \.directory.subtitleText)
                        colorRow("Child text",      kp: \.directory.childText)
                        colorRow("More text",       kp: \.directory.moreText)
                        colorRow("Top face color",  kp: \.directory.topColor)
                        colorRow("Top emission",    kp: \.directory.topEmission)
                    }
                    colorSection("Files") {
                        colorRow("Side color",       kp: \.file.sideColor)
                        colorRow("Top background",   kp: \.file.topBackground)
                        colorRow("Top border",       kp: \.file.topBorder)
                        colorRow("Badge text",       kp: \.file.badgeText)
                        colorRow("Badge background", kp: \.file.badgeBackground)
                        colorRow("Name text",        kp: \.file.nameText)
                        colorRow("Type text",        kp: \.file.typeText)
                        colorRow("Size text",        kp: \.file.sizeText)
                        colorRow("Date text",        kp: \.file.dateText)
                    }
                }
                .padding(.bottom, 16)
            }
            .disabled(isBuiltIn)
            .opacity(isBuiltIn ? 0.55 : 1)
        }
    }

    // MARK: - Color rows

    @ViewBuilder
    private func colorSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 20)
                .padding(.top, 16)
                .padding(.bottom, 6)
            content()
        }
    }

    private func colorRow(_ label: String, kp: WritableKeyPath<Theme, String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .frame(width: 160, alignment: .leading)

            ColorPicker("", selection: colorBinding(kp), supportsOpacity: true)
                .labelsHidden()
                .frame(width: 28)

            Text(currentHex(kp).uppercased())
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    private func currentHex(_ kp: KeyPath<Theme, String>) -> String {
        manager.current[keyPath: kp]
    }

    private func colorBinding(_ kp: WritableKeyPath<Theme, String>) -> Binding<Color> {
        Binding(
            get: {
                Color(hex: manager.current[keyPath: kp])
            },
            set: { newColor in
                guard var theme = manager.customThemes.first(where: { $0.name == selectedName }) else { return }
                theme[keyPath: kp] = newColor.toHex()
                manager.updateCustomTheme(theme)
                manager.current = theme
            }
        )
    }

    // MARK: - Actions

    private func duplicateCurrent() {
        let base = manager.allThemes.first { $0.name == selectedName } ?? .default_
        duplicateTheme(base)
    }

    private func duplicateTheme(_ base: Theme) {
        var copy = base
        copy.name = uniqueName(base.name + " Copy")
        manager.saveCustomTheme(copy)
        selectedName = copy.name
        manager.current = copy
    }

    private func createNewTheme() {
        let trimmed = newThemeName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var theme = Theme.default_
        theme.name = uniqueName(trimmed)
        manager.saveCustomTheme(theme)
        selectedName = theme.name
        manager.current = theme
    }

    private func deleteSelected() {
        guard !isBuiltIn,
              let theme = manager.customThemes.first(where: { $0.name == selectedName })
        else { return }
        manager.deleteCustomTheme(theme)
        selectedName = manager.allThemes.first?.name ?? Theme.default_.name
    }

    private func uniqueName(_ base: String) -> String {
        var name = base; var i = 2
        let existing = Set(manager.allThemes.map(\.name))
        while existing.contains(name) { name = "\(base) \(i)"; i += 1 }
        return name
    }
}

// MARK: - Name field (avoids subscript mutation on private(set) array)

private struct NameField: View {
    let theme: Theme
    let manager: ThemeManager
    @Binding var selectedName: String
    @State private var text: String

    init(theme: Theme, manager: ThemeManager, selectedName: Binding<String>) {
        self.theme = theme
        self.manager = manager
        self._selectedName = selectedName
        self._text = State(initialValue: theme.name)
    }

    var body: some View {
        TextField("Theme name", text: $text)
            .font(.system(size: 15, weight: .semibold))
            .textFieldStyle(.plain)
            .onSubmit { commit() }
            .onChange(of: theme.name) { _, new in text = new }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != theme.name else { return }
        var updated = theme
        let oldName = updated.name
        updated.name = trimmed
        manager.deleteCustomTheme(theme)
        // remove old file by old name then save under new name
        manager.saveCustomTheme(updated)
        if manager.current.name == oldName { manager.current = updated }
        selectedName = trimmed
    }
}
#endif
