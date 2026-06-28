import RealityKit
import CoreGraphics
import CoreText
import Foundation

// MARK: - VolumeNodeComponent

/// Attached to each box entity so tap handlers can retrieve the associated file node.
struct VolumeNodeComponent: Component {
    let fileNode: FileNode
    let boxHeight: Float
}

// MARK: - VolumeNode factory

@MainActor
enum VolumeNode {
    // Cache TextureResource objects; keyed by "face|theme|url" so they invalidate on theme change.
    nonisolated(unsafe) private static let textureCache = NSCache<NSString, TextureResource>()

    static func make(fileNode: FileNode, boxWidth: Float, boxDepth: Float, theme: Theme) async -> ModelEntity {
        let boxHeight: Float = fileNode.isDirectory
            ? Float(min(max(0.35, log2(Double(max(1, fileNode.childCount)) + 1.5) * 0.75), 5.5))
            : 0.12

        // splitFaces: true → 6 submeshes:  0=Front(+Z) 1=Top(+Y) 2=Back(-Z) 3=Bottom(-Y) 4=Right(+X) 5=Left(-X)
        let mesh = MeshResource.generateBox(
            width: boxWidth, height: boxHeight, depth: boxDepth,
            cornerRadius: 0.06, splitFaces: true
        )

        let side   = await makeSideMaterial(fileNode: fileNode, boxWidth: boxWidth, boxHeight: boxHeight, theme: theme)
        let top    = await makeTopMaterial(fileNode: fileNode, theme: theme)
        let bottom = makeBottomMaterial(theme: theme)
        // Order must match RealityKit splitFaces index: [front, top, back, bottom, right, left]
        let materials: [any Material] = [side, top, side, bottom, side, side]

        let entity = ModelEntity(mesh: mesh, materials: materials)
        entity.components.set(VolumeNodeComponent(fileNode: fileNode, boxHeight: boxHeight))
        entity.components.set(CollisionComponent(shapes: [
            ShapeResource.generateBox(size: SIMD3<Float>(boxWidth, boxHeight, boxDepth))
        ]))
        entity.components.set(InputTargetComponent())
        entity.components.set(HoverEffectComponent())
        return entity
    }

    // MARK: - Material builders

    private static func makeSideMaterial(fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) async -> any Material {
        if fileNode.isDirectory,
           let img = drawSideTexture(fileNode: fileNode, boxWidth: boxWidth, boxHeight: boxHeight, theme: theme),
           let tex = await loadTexture(img, key: "side|\(theme.name)|\(fileNode.url.path)") {
            var mat = UnlitMaterial()
            mat.color = .init(tint: .white, texture: MaterialParameters.Texture(tex))
            return mat
        }
        let cg = CGColor.from(hex: theme.file.sideColor) ?? CGColor(srgbRed: 0.06, green: 0.10, blue: 0.08, alpha: 1)
        return SimpleMaterial(color: rkColor(cg), roughness: 1.0, isMetallic: false)
    }

    private static func makeTopMaterial(fileNode: FileNode, theme: Theme) async -> any Material {
        if fileNode.isDirectory {
            var mat = PhysicallyBasedMaterial()
            let topCG  = CGColor.from(hex: theme.directory.topColor)    ?? CGColor(srgbRed: 0.18, green: 0.38, blue: 0.82, alpha: 1)
            let emitCG = CGColor.from(hex: theme.directory.topEmission) ?? CGColor(gray: 0.05, alpha: 1)
            mat.baseColor      = .init(tint: rkColor(topCG))
            mat.emissiveColor  = .init(color: rkColor(emitCG))
            mat.emissiveIntensity = 1.5
            mat.roughness      = .init(floatLiteral: 1.0)
            mat.metallic       = .init(floatLiteral: 0.0)
            return mat
        }
        if let img = drawFileTopTexture(fileNode: fileNode, theme: theme),
           let tex = await loadTexture(img, key: "top|\(theme.name)|\(fileNode.url.path)") {
            var mat = UnlitMaterial()
            mat.color = .init(tint: .white, texture: MaterialParameters.Texture(tex))
            return mat
        }
        let cg = CGColor.from(hex: theme.file.topBackground) ?? CGColor(gray: 0.05, alpha: 1)
        return UnlitMaterial(color: rkColor(cg))
    }

    private static func makeBottomMaterial(theme: Theme) -> any Material {
        let cg = CGColor.from(hex: theme.scene.bottomFace) ?? CGColor(gray: 0.04, alpha: 1)
        return SimpleMaterial(color: rkColor(cg), roughness: 1.0, isMetallic: false)
    }

    // MARK: - Texture cache

    private static func loadTexture(_ image: CGImage, key: String) async -> TextureResource? {
        let k = key as NSString
        if let cached = textureCache.object(forKey: k) { return cached }
        guard let tex = try? await TextureResource(image: image, withName: key,
                                                   options: .init(semantic: .color)) else { return nil }
        textureCache.setObject(tex, forKey: k)
        return tex
    }

    // MARK: - Cross-platform color helper

    private static func rkColor(_ cg: CGColor) -> Material.Color {
        #if os(macOS)
        return Material.Color(cgColor: cg) ?? .black
        #else
        return Material.Color(cgColor: cg)
        #endif
    }

    // MARK: - Side texture (directories) — Core Graphics

    private static func drawSideTexture(fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) -> CGImage? {
        let t  = theme.directory
        let w  = 512
        let h  = max(64, Int(CGFloat(w) * CGFloat(boxHeight) / CGFloat(boxWidth)))
        let wf = CGFloat(w), hf = CGFloat(h)
        guard let ctx = bitmapContext(width: w, height: h) else { return nil }

        ctx.setFillColor(CGColor.from(hex: t.sideBackground) ?? CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: wf, height: hf))

        stroke(ctx: ctx, rect: CGRect(x: 2, y: 2, width: wf - 4, height: hf - 4), radius: 4,
               color: CGColor.from(hex: t.sideBorder) ?? CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1), lineWidth: 2)

        drawLine(ctx: ctx, text: fileNode.name, font: sysFontBold(36),
                 color: CGColor.from(hex: t.nameText) ?? CGColor(gray: 1, alpha: 1),
                 x: 20, y: hf - 52, maxWidth: wf - 40, truncate: true)

        var subtitle = "\(fileNode.childCount) items"
        let parts: [String] = [
            fileNode.folderCount > 0 ? "\(fileNode.folderCount) folder\(fileNode.folderCount == 1 ? "" : "s")" : nil,
            fileNode.fileCount   > 0 ? "\(fileNode.fileCount) file\(fileNode.fileCount == 1 ? "" : "s")"       : nil
        ].compactMap { $0 }
        if !parts.isEmpty { subtitle += "  ·  " + parts.joined(separator: "  ·  ") }

        drawLine(ctx: ctx, text: subtitle, font: sysFont(20),
                 color: CGColor.from(hex: t.subtitleText) ?? CGColor(gray: 0.55, alpha: 1),
                 x: 20, y: hf - 100, maxWidth: wf - 40, truncate: false)

        ctx.setStrokeColor(CGColor(gray: 0.25, alpha: 1)); ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 20, y: hf - 114)); ctx.addLine(to: CGPoint(x: wf - 20, y: hf - 114)); ctx.strokePath()

        let rowH: CGFloat = 30, listTop: CGFloat = hf - 142
        let maxRows = max(0, Int((listTop - 20) / rowH))
        var y = listTop
        for item in fileNode.topChildren.prefix(maxRows) {
            drawLine(ctx: ctx, text: item, font: sysFontMono(18),
                     color: CGColor.from(hex: t.childText) ?? CGColor(gray: 0.8, alpha: 1),
                     x: 24, y: y, maxWidth: wf - 48, truncate: true)
            y -= rowH
        }
        if fileNode.topChildren.count > maxRows && maxRows > 0 {
            drawLine(ctx: ctx, text: "+ \(fileNode.topChildren.count - maxRows) more…", font: sysFont(15),
                     color: CGColor.from(hex: t.moreText) ?? CGColor(gray: 0.4, alpha: 1),
                     x: 24, y: y, maxWidth: wf - 48, truncate: false)
        }
        return ctx.makeImage()
    }

    // MARK: - Top texture (files) — Core Graphics

    private static func drawFileTopTexture(fileNode: FileNode, theme: Theme) -> CGImage? {
        let t = theme.file
        let w = 512, h = 512
        let wf = CGFloat(w), hf = CGFloat(h)
        guard let ctx = bitmapContext(width: w, height: h) else { return nil }

        ctx.setFillColor(CGColor.from(hex: t.topBackground) ?? CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: wf, height: hf))

        stroke(ctx: ctx, rect: CGRect(x: 4, y: 4, width: wf - 8, height: hf - 8), radius: 6,
               color: CGColor.from(hex: t.topBorder) ?? CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1), lineWidth: 3)

        let ext = fileNode.url.pathExtension.uppercased()
        if !ext.isEmpty {
            let badgeColor = CGColor.from(hex: t.badgeText) ?? CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
            let badgeLine  = ctLine(text: ext, font: sysFontMono(22), color: badgeColor)
            let bounds     = CTLineGetBoundsWithOptions(badgeLine, [])
            let pad: CGFloat = 10
            let bRect = CGRect(x: wf - bounds.width - pad * 2 - 12, y: hf - bounds.height - 20,
                               width: bounds.width + pad * 2, height: bounds.height + 6)
            let bPath = CGPath(roundedRect: bRect, cornerWidth: 5, cornerHeight: 5, transform: nil)
            ctx.addPath(bPath); ctx.setFillColor(CGColor.from(hex: t.badgeBackground) ?? CGColor(gray: 0.2, alpha: 1)); ctx.fillPath()
            ctx.addPath(bPath); ctx.setStrokeColor(badgeColor.copy(alpha: 0.7) ?? badgeColor); ctx.setLineWidth(1); ctx.strokePath()
            ctx.textPosition = CGPoint(x: bRect.minX + pad, y: bRect.minY + 3); CTLineDraw(badgeLine, ctx)
        }

        drawLine(ctx: ctx, text: fileNode.name, font: sysFontBold(32),
                 color: CGColor.from(hex: t.nameText) ?? CGColor(gray: 1, alpha: 1),
                 x: 20, y: hf - 60, maxWidth: wf - 40, truncate: true)

        ctx.setStrokeColor(CGColor(gray: 0.25, alpha: 1)); ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 20, y: hf - 96)); ctx.addLine(to: CGPoint(x: wf - 20, y: hf - 96)); ctx.strokePath()

        drawLine(ctx: ctx, text: fileTypeLabel(ext: ext), font: sysFont(20),
                 color: CGColor.from(hex: t.typeText) ?? CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
                 x: 20, y: hf - 128, maxWidth: wf - 40, truncate: false)
        drawLine(ctx: ctx, text: fileSizeString(url: fileNode.url), font: sysFontMono(24),
                 color: CGColor.from(hex: t.sizeText) ?? CGColor(gray: 0.75, alpha: 1),
                 x: 20, y: hf - 180, maxWidth: wf - 40, truncate: false)

        if let mod = try? fileNode.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .short
            drawLine(ctx: ctx, text: "Modified \(fmt.string(from: mod))", font: sysFont(16),
                     color: CGColor.from(hex: t.dateText) ?? CGColor(gray: 0.4, alpha: 1),
                     x: 20, y: hf - 216, maxWidth: wf - 40, truncate: false)
        }
        return ctx.makeImage()
    }

    // MARK: - Core Graphics / Core Text helpers

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    private static func stroke(ctx: CGContext, rect: CGRect, radius: CGFloat, color: CGColor, lineWidth: CGFloat) {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setStrokeColor(color); ctx.setLineWidth(lineWidth); ctx.strokePath()
    }

    private static func ctLine(text: String, font: CTFont, color: CGColor) -> CTLine {
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        return CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!)
    }

    private static func drawLine(ctx: CGContext, text: String, font: CTFont, color: CGColor,
                                  x: CGFloat, y: CGFloat, maxWidth: CGFloat, truncate: Bool) {
        let line = ctLine(text: text, font: font, color: color)
        let drawn = truncate ? (CTLineCreateTruncatedLine(line, Double(maxWidth), .end, nil) ?? line) : line
        ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(drawn, ctx)
    }

    private static func sysFontBold(_ size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil) ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }
    private static func sysFont(_ size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.user, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }
    private static func sysFontMono(_ size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.userFixedPitch, size, nil) ?? CTFontCreateWithName("Menlo-Regular" as CFString, size, nil)
    }

    // MARK: - File helpers

    private static func fileTypeLabel(ext: String) -> String {
        guard !ext.isEmpty else { return "Document" }
        let map: [String: String] = [
            "swift": "Swift Source", "m": "Obj-C Source", "h": "Header",
            "c": "C Source", "cpp": "C++ Source", "py": "Python Script",
            "js": "JavaScript", "ts": "TypeScript", "json": "JSON",
            "xml": "XML", "plist": "Property List", "yaml": "YAML", "yml": "YAML",
            "md": "Markdown", "txt": "Plain Text", "rtf": "Rich Text",
            "pdf": "PDF Document", "png": "PNG Image", "jpg": "JPEG Image",
            "jpeg": "JPEG Image", "gif": "GIF Image", "heic": "HEIC Image",
            "svg": "SVG Image", "mp4": "MPEG-4 Video", "mov": "QuickTime Movie",
            "mp3": "MP3 Audio", "aac": "AAC Audio", "wav": "WAV Audio",
            "zip": "ZIP Archive", "tar": "TAR Archive", "gz": "GZip Archive",
            "dmg": "Disk Image", "pkg": "Installer Package",
            "app": "Application", "framework": "Framework", "dylib": "Dynamic Library",
            "xcodeproj": "Xcode Project", "xcworkspace": "Xcode Workspace",
            "storyboard": "Interface Builder", "xib": "Interface Builder",
            "html": "HTML", "css": "Stylesheet", "sh": "Shell Script",
            "rb": "Ruby Script", "go": "Go Source", "rs": "Rust Source"
        ]
        return map[ext.lowercased()] ?? "\(ext) File"
    }

    private static func fileSizeString(url: URL) -> String {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return "—" }
        let bytes = Int64(size)
        for (label, factor): (String, Int64) in [("GB", 1_073_741_824), ("MB", 1_048_576), ("KB", 1_024)] {
            if bytes >= factor {
                let val = Double(bytes) / Double(factor)
                return String(format: val < 10 ? "%.1f \(label)" : "%.0f \(label)", val)
            }
        }
        return "\(bytes) bytes"
    }
}
