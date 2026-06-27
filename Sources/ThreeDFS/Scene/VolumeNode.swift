import SceneKit
import AppKit

final class VolumeNode: SCNNode {
    let fileNode: FileNode
    let boxHeight: Float

    // Cache key pairs theme name + URL so cached textures are invalidated on theme switch.
    nonisolated(unsafe) private static let sideTextureCache = NSCache<NSString, NSImage>()
    nonisolated(unsafe) private static let fileTopTextureCache = NSCache<NSString, NSImage>()

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
            mat.diffuse.contents = NSColor(hex: theme.file.sideColor)
                ?? NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.08, alpha: 1)
        }
        mat.lightingModel = .lambert
        mat.isDoubleSided = false
        return mat
    }

    private static func makeTopMaterial(fileNode: FileNode, theme: Theme) -> SCNMaterial {
        let mat = SCNMaterial()
        if fileNode.isDirectory {
            mat.diffuse.contents = NSColor(hex: theme.directory.topColor)
            mat.emission.contents = NSColor(hex: theme.directory.topEmission)
        } else {
            mat.diffuse.contents = fileTopTexture(for: fileNode, theme: theme)
        }
        mat.lightingModel = .lambert
        return mat
    }

    private static func makeBottomMaterial(theme: Theme) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(hex: theme.scene.bottomFace)
            ?? NSColor(white: 0.04, alpha: 1)
        mat.lightingModel = .lambert
        return mat
    }

    // MARK: - Side texture (directories)

    private static func sideTexture(for fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) -> NSImage {
        let key = "\(theme.name)|\(fileNode.url.path)" as NSString
        if let cached = sideTextureCache.object(forKey: key) { return cached }
        let image = drawSideTexture(fileNode: fileNode, boxWidth: boxWidth, boxHeight: boxHeight, theme: theme)
        sideTextureCache.setObject(image, forKey: key)
        return image
    }

    private static func drawSideTexture(fileNode: FileNode, boxWidth: Float, boxHeight: Float, theme: Theme) -> NSImage {
        let t = theme.directory
        let w: CGFloat = 512
        let h: CGFloat = max(64, w * CGFloat(boxHeight) / CGFloat(boxWidth))
        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        defer { image.unlockFocus() }

        (NSColor(hex: t.sideBackground) ?? .black).setFill()
        NSRect(origin: .zero, size: NSSize(width: w, height: h)).fill()

        (NSColor(hex: t.sideBorder) ?? .blue).setStroke()
        let border = NSBezierPath(roundedRect: NSRect(x: 2, y: 2, width: w - 4, height: h - 4), xRadius: 4, yRadius: 4)
        border.lineWidth = 2
        border.stroke()

        let truncPara = NSMutableParagraphStyle()
        truncPara.lineBreakMode = .byTruncatingTail

        // Name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 36),
            .foregroundColor: NSColor(hex: t.nameText) ?? .white,
            .paragraphStyle: truncPara
        ]
        NSAttributedString(string: fileNode.name, attributes: nameAttrs)
            .draw(in: NSRect(x: 20, y: h - 68, width: w - 40, height: 48))

        // Subtitle
        var subtitle = "\(fileNode.childCount) items"
        let parts: [String] = [
            fileNode.folderCount > 0 ? "\(fileNode.folderCount) folder\(fileNode.folderCount == 1 ? "" : "s")" : nil,
            fileNode.fileCount > 0   ? "\(fileNode.fileCount) file\(fileNode.fileCount == 1 ? "" : "s")"       : nil
        ].compactMap { $0 }
        if !parts.isEmpty { subtitle += "  ·  " + parts.joined(separator: "  ·  ") }
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .light),
            .foregroundColor: NSColor(hex: t.subtitleText) ?? .gray
        ]
        NSAttributedString(string: subtitle, attributes: subAttrs)
            .draw(at: NSPoint(x: 20, y: h - 100))

        // Divider
        NSColor(white: 0.25, alpha: 1).setStroke()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 20, y: h - 114))
        line.line(to: NSPoint(x: w - 20, y: h - 114))
        line.lineWidth = 0.5
        line.stroke()

        // Children list
        let itemAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor(hex: t.childText) ?? .lightGray,
            .paragraphStyle: truncPara
        ]
        let moreAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .light),
            .foregroundColor: NSColor(hex: t.moreText) ?? .gray
        ]

        let rowHeight: CGFloat = 30
        let listTop: CGFloat = h - 142
        let maxRows = max(0, Int((listTop - 20) / rowHeight))
        var y: CGFloat = listTop
        for item in fileNode.topChildren.prefix(maxRows) {
            NSAttributedString(string: item, attributes: itemAttrs)
                .draw(in: NSRect(x: 24, y: y, width: w - 48, height: 24))
            y -= rowHeight
        }
        if fileNode.topChildren.count > maxRows && maxRows > 0 {
            NSAttributedString(string: "+ \(fileNode.topChildren.count - maxRows) more…", attributes: moreAttrs)
                .draw(at: NSPoint(x: 24, y: y))
        }

        return image
    }

    // MARK: - Top texture (files)

    private static func fileTopTexture(for fileNode: FileNode, theme: Theme) -> NSImage {
        let key = "\(theme.name)|\(fileNode.url.path)" as NSString
        if let cached = fileTopTextureCache.object(forKey: key) { return cached }
        let image = drawFileTopTexture(fileNode: fileNode, theme: theme)
        fileTopTextureCache.setObject(image, forKey: key)
        return image
    }

    private static func drawFileTopTexture(fileNode: FileNode, theme: Theme) -> NSImage {
        let t = theme.file
        let w: CGFloat = 512
        let h: CGFloat = 512
        let image = NSImage(size: NSSize(width: w, height: h))
        image.lockFocus()
        defer { image.unlockFocus() }

        (NSColor(hex: t.topBackground) ?? .black).setFill()
        NSRect(origin: .zero, size: NSSize(width: w, height: h)).fill()

        (NSColor(hex: t.topBorder) ?? .green).setStroke()
        NSBezierPath(roundedRect: NSRect(x: 4, y: 4, width: w - 8, height: h - 8), xRadius: 6, yRadius: 6)
            .apply { $0.lineWidth = 3; $0.stroke() }

        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byTruncatingMiddle

        // Extension badge
        let ext = fileNode.url.pathExtension.uppercased()
        if !ext.isEmpty {
            let badgeColor = NSColor(hex: t.badgeText) ?? .green
            let badgeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 22, weight: .bold),
                .foregroundColor: badgeColor
            ]
            let badgeStr = NSAttributedString(string: ext, attributes: badgeAttrs)
            let badgeSize = badgeStr.size()
            let pad: CGFloat = 10
            let badgeRect = NSRect(
                x: w - badgeSize.width - pad * 2 - 12,
                y: h - badgeSize.height - 20,
                width: badgeSize.width + pad * 2,
                height: badgeSize.height + 6
            )
            (NSColor(hex: t.badgeBackground) ?? .darkGray).setFill()
            NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5).fill()
            badgeColor.withAlphaComponent(0.7).setStroke()
            NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5).stroke()
            badgeStr.draw(at: NSPoint(x: badgeRect.minX + pad, y: badgeRect.minY + 3))
        }

        // File name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 32),
            .foregroundColor: NSColor(hex: t.nameText) ?? .white,
            .paragraphStyle: para
        ]
        NSAttributedString(string: fileNode.name, attributes: nameAttrs)
            .draw(in: NSRect(x: 20, y: h - 80, width: w - 40, height: 44))

        // Divider
        NSColor(white: 0.25, alpha: 1).setStroke()
        let div = NSBezierPath()
        div.move(to: NSPoint(x: 20, y: h - 96))
        div.line(to: NSPoint(x: w - 20, y: h - 96))
        div.lineWidth = 0.5
        div.stroke()

        // File type
        let typeLabel = fileTypeLabel(ext: ext)
        let typeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .light),
            .foregroundColor: NSColor(hex: t.typeText) ?? .green
        ]
        NSAttributedString(string: typeLabel, attributes: typeAttrs)
            .draw(at: NSPoint(x: 20, y: h - 128))

        // File size
        let sizeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor(hex: t.sizeText) ?? .lightGray
        ]
        NSAttributedString(string: fileSizeString(url: fileNode.url), attributes: sizeAttrs)
            .draw(at: NSPoint(x: 20, y: h - 180))

        // Modified date
        if let mod = try? fileNode.url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .light),
                .foregroundColor: NSColor(hex: t.dateText) ?? .gray
            ]
            NSAttributedString(string: "Modified \(fmt.string(from: mod))", attributes: dateAttrs)
                .draw(at: NSPoint(x: 20, y: h - 216))
        }

        return image
    }

    // MARK: - Helpers

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

private extension NSBezierPath {
    func apply(_ block: (NSBezierPath) -> Void) { block(self) }
}
