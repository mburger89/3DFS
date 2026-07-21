import Foundation

enum FileSystemScanner {
    /// Scan `url`'s direct children.
    /// Uses `index` as a fast path for child metadata so indexed directories return
    /// instantly without additional per-child disk reads.
    static func scan(url: URL, index: FileSystemIndex?) async -> [FileNode] {
        let raw = await Task.detached(priority: .userInitiated) {
            scanSync(url: url)
        }.value

        guard let index else { return raw }

        // Overlay cached metadata (childCount, topChildren) from the index.
        // Entries that aren't indexed yet keep their live-scanned values.
        var enriched: [FileNode] = []
        enriched.reserveCapacity(raw.count)
        for node in raw {
            if node.isDirectory, let entry = await index.entry(for: node.url) {
                enriched.append(FileNode(
                    url: node.url,
                    isDirectory: true,
                    childCount: entry.childCount,
                    folderCount: entry.folderCount,
                    fileCount: entry.fileCount,
                    topChildren: entry.topChildren
                ))
            } else {
                enriched.append(node)
            }
        }
        return enriched
    }

    private static func scanSync(url: URL) -> [FileNode] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .isPackageKey]

        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants]
        ) else { return [] }

        var nodes: [FileNode] = []
        let keySet = Set(keys)
        let gcKeys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        let gcKeySet = Set(gcKeys)

        for childURL in contents.sorted(by: { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }) {
            let rv = try? childURL.resourceValues(forKeys: keySet)
            guard !(rv?.isHidden ?? false) else { continue }

            let isDir = rv?.isDirectory ?? false
            let isPkg = rv?.isPackage ?? false

            if isDir && !isPkg {
                let grandChildren = (try? fm.contentsOfDirectory(
                    at: childURL,
                    includingPropertiesForKeys: gcKeys,
                    options: [.skipsHiddenFiles]
                )) ?? []
                // Single pass: collect names + isDir flag, then sort once for topChildren.
                var folders = 0
                var items: [(name: String, isDir: Bool)] = []
                items.reserveCapacity(grandChildren.count)
                for gc in grandChildren {
                    let rv = try? gc.resourceValues(forKeys: gcKeySet)
                    let isGcDir = (rv?.isDirectory ?? false) && !(rv?.isPackage ?? false)
                    if isGcDir { folders += 1 }
                    items.append((gc.lastPathComponent, isGcDir))
                }
                items.sort { $0.name.lowercased() < $1.name.lowercased() }
                let topChildren = items.prefix(8).map { $0.name }
                nodes.append(FileNode(
                    url: childURL,
                    isDirectory: true,
                    childCount: grandChildren.count,
                    folderCount: folders,
                    fileCount: grandChildren.count - folders,
                    topChildren: Array(topChildren)
                ))
            } else {
                nodes.append(FileNode(url: childURL, isDirectory: false))
            }
        }

        return nodes
    }
}
