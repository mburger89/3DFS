import Foundation

struct FileNode: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let name: String
    let isDirectory: Bool
    let childCount: Int
    let folderCount: Int
    let fileCount: Int
    let topChildren: [String]

    init(url: URL, isDirectory: Bool = true, childCount: Int = 0, folderCount: Int = 0, fileCount: Int = 0, topChildren: [String] = []) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent
        self.isDirectory = isDirectory
        self.childCount = childCount
        self.folderCount = folderCount
        self.fileCount = fileCount
        self.topChildren = topChildren
    }

    func hash(into hasher: inout Hasher) { hasher.combine(url) }
    static func == (lhs: FileNode, rhs: FileNode) -> Bool { lhs.url == rhs.url }

    static func root() -> FileNode {
        FileNode(url: FileManager.default.homeDirectoryForCurrentUser)
    }
}
