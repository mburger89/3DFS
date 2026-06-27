import Foundation

/// Lightweight eagerly-scanned index of the filesystem.
/// Stores only childCount + top 8 child names per directory — no file contents.
actor FileSystemIndex {
    struct Entry: Sendable {
        let childCount: Int
        let folderCount: Int
        let fileCount: Int
        let topChildren: [String]
    }

    private var entries: [URL: Entry] = [:]
    private var scanTask: Task<Void, Never>?

    // Max recursion depth from the scan root.
    private let maxDepth = 4

    // MARK: - Public API

    func entry(for url: URL) -> Entry? {
        entries[url]
    }

    func startScan(from root: URL) {
        scanTask?.cancel()
        entries.removeAll(keepingCapacity: true)
        scanTask = Task { [weak self] in
            await self?.recursiveScan(url: root, depth: 0)
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
    }

    // MARK: - Internal

    private func recursiveScan(url: URL, depth: Int) async {
        guard !Task.isCancelled else { return }

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .isPackageKey]

        guard let children = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsSubdirectoryDescendants]
        ) else { return }

        // Filter hidden and sort for stable ordering
        let visible = children
            .filter { child in
                let rv = try? child.resourceValues(forKeys: Set(keys))
                return !(rv?.isHidden ?? false)
            }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }

        let topChildren = visible.prefix(8).map { $0.lastPathComponent }
        var folders = 0
        for child in visible {
            let rv = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            if (rv?.isDirectory ?? false) && !(rv?.isPackage ?? false) { folders += 1 }
        }
        entries[url] = Entry(
            childCount: visible.count,
            folderCount: folders,
            fileCount: visible.count - folders,
            topChildren: Array(topChildren)
        )

        guard depth < maxDepth else { return }

        // Recurse into visible subdirectories (non-package)
        for child in visible {
            guard !Task.isCancelled else { return }
            let rv = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            let isDir = rv?.isDirectory ?? false
            let isPkg = rv?.isPackage ?? false
            if isDir && !isPkg {
                // Yield so we don't monopolize the actor
                await Task.yield()
                await recursiveScan(url: child, depth: depth + 1)
            }
        }
    }
}
