import SceneKit
import CoreGraphics
import CoreText

final class VolumeNode: SCNNode {
    let fileNode: FileNode
    let boxHeight: Float

    // Cache keys pair theme name + URL so cached textures invalidate on theme switch.
    nonisolated(unsafe) private static let sideTextureCache    = NSCache<NSString, ImageBox>()
    nonisolated(unsafe) private static let fileTopTextureCache = NSCache<NSString, ImageBox>()

    init(fileNode: FileNode, boxWidth: Float, boxDepth: Float, theme: Theme) {
        self.fileNode = fileNode

        if fileNode.isDirectory {
            let raw = log2(Double(max(1, fileNode.childCount)) + 1.5) * 0.75
            self.boxHeight = Float(min(max(0.35, raw), 5.5))
        } else {
            self.boxHeight = 0.12
        }

        super.init()

        let box = SCNBox(
            width: CGFloat(boxWidth),
            height: CGFloat(boxHeight),
            length: CGFloat(boxDepth),
            chamferRadius: 0.06
        )

        let side   = VolumeNode.makeSideMaterial(fileNode: fileNode, boxWidth: boxWidth, boxHeight: self.boxHeight, theme: theme)
        let top    = VolumeNode.makeTopMaterial(fileNode: fileNode, theme: theme)
        let bottom = VolumeNode.makeBottomMaterial(theme: theme)

        // SCNBox material order: front, right, back, left, top, bottom
        box.materials = [side, side, side, side, top, bottom]

        addChildNode(SCNNode(geometry: box))
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Highlight

    func setHighlighted(_ on: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.12
        childNodes.first?.scale = on
            ? SCNVector3(1.06, 1.06, 1.06)
            : SCNVector3(1, 1, 1)
        SCNTransaction.commit()
    }

    // MARK: - Materials

    private static func makeSideMaterial(fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) -> SCNMaterial {
        let mat = SCNMaterial()
        if fileNode.isDirectory {
            mat.diffuse.contents = sideTexture(for: fileNode, boxWidth: boxWidth, boxHeight: boxHeight, theme: theme)
        } else {
            mat.diffuse.contents = CGColor.from(hex: theme.file.sideColor)
                ?? CGColor(srgbRed: 0.06, green: 0.10, blue: 0.08, alpha: 1)
        }
        mat.lightingModel = .lambert
        mat.isDoubleSided = false
        return mat
    }

    private static func makeTopMaterial(fileNode: FileNode, theme: Theme) -> SCNMaterial {
        let mat = SCNMaterial()
        if fileNode.isDirectory {
            mat.diffuse.contents = CGColor.from(hex: theme.directory.topColor)
            mat.emission.contents = CGColor.from(hex: theme.directory.topEmission)
        } else {
            mat.diffuse.contents = fileTopTexture(for: fileNode, theme: theme)
        }
        mat.lightingModel = .lambert
        return mat
    }

    private static func makeBottomMaterial(theme: Theme) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = CGColor.from(hex: theme.scene.bottomFace)
            ?? CGColor(gray: 0.04, alpha: 1)
        mat.lightingModel = .lambert
        return mat
    }

    // MARK: - Side texture (directories)

    private static func sideTexture(for fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) -> CGImage? {
        let key = "\(theme.name)|\(fileNode.url.path)" as NSString
        if let cached = sideTextureCache.object(forKey: key) { return cached.image }
        guard let image = drawSideTexture(fileNode: fileNode, boxWidth: boxWidth, boxHeight: boxHeight, theme: theme) else { return nil }
        sideTextureCache.setObject(ImageBox(image), forKey: key)
        return image
    }

    private static func drawSideTexture(fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) -> CGImage? {
        let t = theme.directory
        let w = 512
        let h = max(64, Int(CGFloat(w) * CGFloat(boxHeight) / CGFloat(boxWidth)))
        let wf = CGFloat(w), hf = CGFloat(h)

        guard let ctx = bitmapContext(width: w, height: h) else { return nil }

        // Background
        ctx.setFillColor(CGColor.from(hex: t.sideBackground) ?? CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: wf, height: hf))

        // Border
        stroke(ctx: ctx,
               rect: CGRect(x: 2, y: 2, width: wf - 4, height: hf - 4), radius: 4,
               color: CGColor.from(hex: t.sideBorder) ?? CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
               lineWidth: 2)

        // Name (bold, large)
        drawLine(ctx: ctx, text: fileNode.name,
                 font: sysFontBold(36),
                 color: CGColor.from(hex: t.nameText) ?? CGColor(gray: 1, alpha: 1),
                 x: 20, y: hf - 52, maxWidth: wf - 40, truncate: true)

        // Subtitle
        var subtitle = "\(fileNode.childCount) items"
        let parts: [String] = [
            fileNode.folderCount > 0 ? "\(fileNode.folderCount) folder\(fileNode.folderCount == 1 ? "" : "s")" : nil,
            fileNode.fileCount   > 0 ? "\(fileNode.fileCount) file\(fileNode.fileCount == 1 ? "" : "s")"       : nil
        ].compactMap { $0 }
        if !parts.isEmpty { subtitle += "  ·  " + parts.joined(separator: "  ·  ") }

        drawLine(ctx: ctx, text: subtitle,
                 font: sysFont(20),
                 color: CGColor.from(hex: t.subtitleText) ?? CGColor(gray: 0.55, alpha: 1),
                 x: 20, y: hf - 100, maxWidth: wf - 40, truncate: false)

        // Divider
        ctx.setStrokeColor(CGColor(gray: 0.25, alpha: 1))
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 20, y: hf - 114))
        ctx.addLine(to: CGPoint(x: wf - 20, y: hf - 114))
        ctx.strokePath()

        // Children list
        let rowHeight: CGFloat = 30
        let listTop: CGFloat = hf - 142
        let maxRows = max(0, Int((listTop - 20) / rowHeight))
        var y = listTop

        for item in fileNode.topChildren.prefix(maxRows) {
            drawLine(ctx: ctx, text: item,
                     font: sysFontMono(18),
                     color: CGColor.from(hex: t.childText) ?? CGColor(gray: 0.8, alpha: 1),
                     x: 24, y: y, maxWidth: wf - 48, truncate: true)
            y -= rowHeight
        }
        if fileNode.topChildren.count > maxRows && maxRows > 0 {
            drawLine(ctx: ctx, text: "+ \(fileNode.topChildren.count - maxRows) more…",
                     font: sysFont(15),
                     color: CGColor.from(hex: t.moreText) ?? CGColor(gray: 0.4, alpha: 1),
                     x: 24, y: y, maxWidth: wf - 48, truncate: false)
        }

        return ctx.makeImage()
    }

    // MARK: - Top texture (files)

    private static func fileTopTexture(for fileNode: FileNode, theme: Theme) -> CGImage? {
        let key = "\(theme.name)|\(fileNode.url.path)" as NSString
        if let cached = fileTopTextureCache.object(forKey: key) { return cached.image }
        guard let image = drawFileTopTexture(fileNode: fileNode, theme: theme) else { return nil }
        fileTopTextureCache.setObject(ImageBox(image), forKey: key)
        return image
    }

    private static func drawFileTopTexture(fileNode: FileNode, theme: Theme) -> CGImage? {
        let t = theme.file
        let w = 512, h = 512
        let wf = CGFloat(w), hf = CGFloat(h)

        guard let ctx = bitmapContext(width: w, height: h) else { return nil }

        // Background
        ctx.setFillColor(CGColor.from(hex: t.topBackground) ?? CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: wf, height: hf))

        // Border
        stroke(ctx: ctx,
               rect: CGRect(x: 4, y: 4, width: wf - 8, height: hf - 8), radius: 6,
               color: CGColor.from(hex: t.topBorder) ?? CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
               lineWidth: 3)

        // Extension badge
        let ext = fileNode.url.pathExtension.uppercased()
        if !ext.isEmpty {
            let badgeColor = CGColor.from(hex: t.badgeText) ?? CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
            let badgeLine  = ctLine(text: ext, font: sysFontMono(22), color: badgeColor)
            let bounds     = CTLineGetBoundsWithOptions(badgeLine, [])
            let pad: CGFloat = 10
            let badgeRect = CGRect(x: wf - bounds.width - pad * 2 - 12,
                                   y: hf - bounds.height - 20,
                                   width: bounds.width + pad * 2,
                                   height: bounds.height + 6)
            let badgePath = CGPath(roundedRect: badgeRect, cornerWidth: 5, cornerHeight: 5, transform: nil)

            ctx.addPath(badgePath)
            ctx.setFillColor(CGColor.from(hex: t.badgeBackground) ?? CGColor(gray: 0.2, alpha: 1))
            ctx.fillPath()
            ctx.addPath(badgePath)
            ctx.setStrokeColor(badgeColor.copy(alpha: 0.7) ?? badgeColor)
            ctx.setLineWidth(1)
            ctx.strokePath()

            ctx.textPosition = CGPoint(x: badgeRect.minX + pad, y: badgeRect.minY + 3)
            CTLineDraw(badgeLine, ctx)
        }

        // File name
        drawLine(ctx: ctx, text: fileNode.name,
                 font: sysFontBold(32),
                 color: CGColor.from(hex: t.nameText) ?? CGColor(gray: 1, alpha: 1),
                 x: 20, y: hf - 60, maxWidth: wf - 40, truncate: true)

        // Divider
        ctx.setStrokeColor(CGColor(gray: 0.25, alpha: 1))
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: 20, y: hf - 96))
        ctx.addLine(to: CGPoint(x: wf - 20, y: hf - 96))
        ctx.strokePath()

        // File type label
        drawLine(ctx: ctx, text: fileTypeLabel(ext: ext),
                 font: sysFont(20),
                 color: CGColor.from(hex: t.typeText) ?? CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
                 x: 20, y: hf - 128, maxWidth: wf - 40, truncate: false)

        // File size
        drawLine(ctx: ctx, text: fileSizeString(url: fileNode.url),
                 font: sysFontMono(24),
                 color: CGColor.from(hex: t.sizeText) ?? CGColor(gray: 0.75, alpha: 1),
                 x: 20, y: hf - 180, maxWidth: wf - 40, truncate: false)

        // Modified date
        if let mod = try? fileNode.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            drawLine(ctx: ctx, text: "Modified \(fmt.string(from: mod))",
                     font: sysFont(16),
                     color: CGColor.from(hex: t.dateText) ?? CGColor(gray: 0.4, alpha: 1),
                     x: 20, y: hf - 216, maxWidth: wf - 40, truncate: false)
        }

        return ctx.makeImage()
    }

    // MARK: - Core Graphics helpers

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    private static func stroke(ctx: CGContext, rect: CGRect, radius: CGFloat, color: CGColor, lineWidth: CGFloat) {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setStrokeColor(color)
        ctx.setLineWidth(lineWidth)
        ctx.strokePath()
    }

    private static func ctLine(text: String, font: CTFont, color: CGColor) -> CTLine {
        let attrs: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        let str = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        return CTLineCreateWithAttributedString(str)
    }

    private static func drawLine(ctx: CGContext, text: String, font: CTFont, color: CGColor,
                                  x: CGFloat, y: CGFloat, maxWidth: CGFloat, truncate: Bool) {
        let line = ctLine(text: text, font: font, color: color)
        let drawn = truncate
            ? (CTLineCreateTruncatedLine(line, Double(maxWidth), .end, nil) ?? line)
            : line
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(drawn, ctx)
    }

    // MARK: - Font helpers

    private static func sysFontBold(_ size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.emphasizedSystem, size, nil)
            ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    }

    private static func sysFont(_ size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.user, size, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
    }

    private static func sysFontMono(_ size: CGFloat) -> CTFont {
        CTFontCreateUIFontForLanguage(.userFixedPitch, size, nil)
            ?? CTFontCreateWithName("Menlo-Regular" as CFString, size, nil)
    }

    // MARK: - Helpers

    private static func fileTypeLabel(ext: String) -> String {
        guard !ext.isEmpty else { return "Document" }
        let map: [String: String] = [
            "swift": "Swift Source",  "m": "Obj-C Source",    "h": "Header",
            "c": "C Source",          "cpp": "C++ Source",    "py": "Python Script",
            "js": "JavaScript",       "ts": "TypeScript",     "json": "JSON",
            "xml": "XML",             "plist": "Property List","yaml": "YAML", "yml": "YAML",
            "md": "Markdown",         "txt": "Plain Text",    "rtf": "Rich Text",
            "pdf": "PDF Document",    "png": "PNG Image",     "jpg": "JPEG Image",
            "jpeg": "JPEG Image",     "gif": "GIF Image",     "heic": "HEIC Image",
            "svg": "SVG Image",       "mp4": "MPEG-4 Video",  "mov": "QuickTime Movie",
            "mp3": "MP3 Audio",       "aac": "AAC Audio",     "wav": "WAV Audio",
            "zip": "ZIP Archive",     "tar": "TAR Archive",   "gz": "GZip Archive",
            "dmg": "Disk Image",      "pkg": "Installer Package",
            "app": "Application",     "framework": "Framework","dylib": "Dynamic Library",
            "xcodeproj": "Xcode Project","xcworkspace": "Xcode Workspace",
            "storyboard": "Interface Builder","xib": "Interface Builder",
            "html": "HTML",           "css": "Stylesheet",    "sh": "Shell Script",
            "rb": "Ruby Script",      "go": "Go Source",      "rs": "Rust Source"
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

// NSCache requires AnyObject values; CGImage is a CF type that needs a class wrapper.
private final class ImageBox: @unchecked Sendable {
    let image: CGImage
    init(_ image: CGImage) { self.image = image }
}
