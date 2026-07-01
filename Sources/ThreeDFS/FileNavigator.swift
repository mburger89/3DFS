import Foundation

@MainActor
final class FileNavigator: ObservableObject {
    @Published private(set) var path: [FileNode] = []
    @Published private(set) var currentChildren: [FileNode] = []
    @Published private(set) var isLoading = false
    @Published private(set) var epoch: UUID = UUID()

    /// True until the user has either granted Full Disk Access or chosen a folder.
    @Published private(set) var needsRootSelection = true

    /// Set to true to present the system folder picker from a containing view's .fileImporter.
    @Published var showingFolderPicker = false

    let index = FileSystemIndex()

    private var securityScopedRoot: URL?
    private let bookmarkKey = "com.maxburger.threedfs.rootBookmark"

    init() {
#if os(macOS)
        // 1. Full Disk Access — best case: start from home dir, no picker needed.
        if FullDiskAccessHelper.check() {
            startFromHome()
            return
        }
#endif
        // 2. Saved bookmark from a previous selection.
        if let data = UserDefaults.standard.data(forKey: bookmarkKey),
           let url = resolveBookmark(data) {
            securityScopedRoot = url
            _ = url.startAccessingSecurityScopedResource()
            needsRootSelection = false
            Task {
                await index.startScan(from: url)
                await navigateTo(FileNode(url: url))
            }
            return
        }
#if os(visionOS)
        // 3. visionOS: fall back to the shared Documents directory (no permission prompt needed).
        startFromDocuments()
#endif
        // 4. Otherwise needsRootSelection stays true → WelcomeView is shown.
    }

    // MARK: - Full Disk Access path (macOS only)

#if os(macOS)
    func useFullDiskAccess() { startFromHome() }

    private func startFromHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        path = []
        needsRootSelection = false
        Task {
            await index.startScan(from: home)
            await navigateTo(FileNode(url: home))
        }
    }
#endif

    // MARK: - visionOS default root

#if os(visionOS)
    private func startFromDocuments() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        path = []
        needsRootSelection = false
        Task {
            await index.startScan(from: docs)
            await navigateTo(FileNode(url: docs))
        }
    }
#endif

    // MARK: - Navigation

    func navigateTo(_ node: FileNode) async {
        guard node.isDirectory else { return }
        isLoading = true
        let children = await FileSystemScanner.scan(url: node.url, index: index)
        path.append(node)
        currentChildren = children
        epoch = UUID()
        isLoading = false
    }

    func navigateBack(toIndex pathIndex: Int) async {
        guard pathIndex < path.count else { return }
        path = Array(path.prefix(pathIndex + 1))
        guard let node = path.last else { return }
        isLoading = true
        let children = await FileSystemScanner.scan(url: node.url, index: index)
        currentChildren = children
        epoch = UUID()
        isLoading = false
    }

    func navigateBack() async {
        guard path.count > 1 else { return }
        await navigateBack(toIndex: path.count - 2)
    }

    var canGoBack: Bool { path.count > 1 }

    // MARK: - Folder picker

    /// Signals the containing view to present the system folder picker via .fileImporter.
    func pickFolder() { showingFolderPicker = true }

    func adoptRoot(_ url: URL) {
        // Persist a bookmark so access survives app restarts.
#if os(macOS)
        if let data = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
#else
        if let data = try? url.bookmarkData() {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
#endif
        securityScopedRoot?.stopAccessingSecurityScopedResource()
        securityScopedRoot = url
        _ = url.startAccessingSecurityScopedResource()
        path = []
        needsRootSelection = false
        Task {
            await index.startScan(from: url)
            await navigateTo(FileNode(url: url))
        }
    }

    // MARK: - Private

    private func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
#if os(macOS)
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale, let fresh = try? url.bookmarkData(options: .withSecurityScope) {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
#else
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale, let fresh = try? url.bookmarkData() {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
#endif
        return url
    }
}
