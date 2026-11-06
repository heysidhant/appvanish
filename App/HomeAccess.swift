import AppKit

/// Remembers the Home folder the person allowed, using a security-scoped bookmark.
enum HomeAccess {
    private static let key = "homeFolderBookmark"

    static var home: URL { URL(fileURLWithPath: RealHome.path, isDirectory: true) }

    /// Reopens access granted earlier. Returns nil if there is none or it no longer works.
    static func restore() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ), isHome(url), url.startAccessingSecurityScopedResource() else {
            return nil
        }
        if isStale { save(url) }
        return url
    }

    /// Asks the person to allow the Home folder. Returns nil if they cancel.
    @MainActor
    static func request() throws -> URL? {
        let panel = NSOpenPanel()
        panel.message = "Select your Home folder so App Vanish can check your Library."
        panel.prompt = "Allow"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = home
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard isHome(url) else { throw AccessError.wrongFolder }
        guard url.startAccessingSecurityScopedResource() else { throw AccessError.denied }
        save(url)
        return url
    }

    static func forget(_ url: URL?) {
        url?.stopAccessingSecurityScopedResource()
        UserDefaults.standard.removeObject(forKey: key)
    }

    private static func isHome(_ url: URL) -> Bool {
        url.resolvingSymlinksInPath().standardizedFileURL.path
            == home.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func save(_ url: URL) {
        if let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    enum AccessError: LocalizedError {
        case wrongFolder
        case denied

        var errorDescription: String? {
            switch self {
            case .wrongFolder: return "That isn't your Home folder. Choose the folder with your name."
            case .denied: return "macOS didn't allow access to that folder."
            }
        }
    }
}
