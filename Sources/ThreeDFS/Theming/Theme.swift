import AppKit

// MARK: - Theme model

struct Theme: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String

    var scene: SceneTheme
    var directory: DirectoryTheme
    var file: FileTheme

    struct SceneTheme: Codable, Hashable {
        var background: String     // hex
        var bottomFace: String
    }

    struct DirectoryTheme: Codable, Hashable {
        var sideBackground: String
        var sideBorder: String
        var nameText: String
        var subtitleText: String
        var childText: String
        var moreText: String
        var topColor: String
        var topEmission: String
    }

    struct FileTheme: Codable, Hashable {
        var sideColor: String
        var topBackground: String
        var topBorder: String
        var badgeText: String
        var badgeBackground: String
        var nameText: String
        var typeText: String
        var sizeText: String
        var dateText: String
    }
}

// MARK: - NSColor helper

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6 || s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        let r, g, b, a: CGFloat
        if s.count == 6 {
            r = CGFloat((value >> 16) & 0xff) / 255
            g = CGFloat((value >> 8)  & 0xff) / 255
            b = CGFloat(value         & 0xff) / 255
            a = 1
        } else {
            r = CGFloat((value >> 24) & 0xff) / 255
            g = CGFloat((value >> 16) & 0xff) / 255
            b = CGFloat((value >> 8)  & 0xff) / 255
            a = CGFloat(value         & 0xff) / 255
        }
        self.init(calibratedRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Built-in themes

extension Theme {
    static let builtIn: [Theme] = [.default_, .vaporWave, .forest, .midnight]

    static let `default_` = Theme(
        name: "Default",
        scene: .init(
            background: "#080B12",
            bottomFace: "#0A0A0A"
        ),
        directory: .init(
            sideBackground: "#0F1421",
            sideBorder:     "#334DBF99",
            nameText:       "#FFFFFF",
            subtitleText:   "#8C8C8C",
            childText:      "#8DBFFF",
            moreText:       "#595959",
            topColor:       "#2E60D1",
            topEmission:    "#0D1F66"
        ),
        file: .init(
            sideColor:       "#0F1A14",
            topBackground:   "#0F1F16",
            topBorder:       "#338C4D80",
            badgeText:       "#59D980",
            badgeBackground: "#1A4D26",
            nameText:        "#FFFFFF",
            typeText:        "#8CD98A",
            sizeText:        "#BFBFBF",
            dateText:        "#666666"
        )
    )

    static let vaporWave = Theme(
        name: "Vapor Wave",
        scene: .init(
            background: "#0D0221",
            bottomFace: "#08011A"
        ),
        directory: .init(
            sideBackground: "#1A0533",
            sideBorder:     "#FF71CE99",
            nameText:       "#FFFFFF",
            subtitleText:   "#B967FF",
            childText:      "#01CDFE",
            moreText:       "#6600CC",
            topColor:       "#CC1177",
            topEmission:    "#660033"
        ),
        file: .init(
            sideColor:       "#0D1A1A",
            topBackground:   "#0D1F26",
            topBorder:       "#05FFA180",
            badgeText:       "#05FFA1",
            badgeBackground: "#0A2918",
            nameText:        "#FFFFFF",
            typeText:        "#05FFA1",
            sizeText:        "#FFFB96",
            dateText:        "#B967FF"
        )
    )

    static let forest = Theme(
        name: "Forest",
        scene: .init(
            background: "#0A140A",
            bottomFace: "#060D06"
        ),
        directory: .init(
            sideBackground: "#0F2010",
            sideBorder:     "#4A8C2A99",
            nameText:       "#E8F5E8",
            subtitleText:   "#7AB87A",
            childText:      "#A8D88A",
            moreText:       "#3D6B3D",
            topColor:       "#2D5A1B",
            topEmission:    "#142A0A"
        ),
        file: .init(
            sideColor:       "#0A1A10",
            topBackground:   "#0F2618",
            topBorder:       "#5AAD3380",
            badgeText:       "#7AD95A",
            badgeBackground: "#1A3D10",
            nameText:        "#F0FFF0",
            typeText:        "#8AD870",
            sizeText:        "#C8D8B8",
            dateText:        "#5A7A5A"
        )
    )

    static let midnight = Theme(
        name: "Midnight",
        scene: .init(
            background: "#000005",
            bottomFace: "#000000"
        ),
        directory: .init(
            sideBackground: "#05050F",
            sideBorder:     "#1A1A4D99",
            nameText:       "#C8C8FF",
            subtitleText:   "#4D4D80",
            childText:      "#3D3D99",
            moreText:       "#2B2B4D",
            topColor:       "#0D0D33",
            topEmission:    "#05051A"
        ),
        file: .init(
            sideColor:       "#050510",
            topBackground:   "#05050F",
            topBorder:       "#1A1A4D80",
            badgeText:       "#3D3D99",
            badgeBackground: "#05050D",
            nameText:        "#B8B8E8",
            typeText:        "#3D3D80",
            sizeText:        "#666680",
            dateText:        "#2B2B4D"
        )
    )
}
