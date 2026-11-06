import Foundation

enum RemovalGuard {
    static func canTrash(_ url: URL) -> Bool {
        allowed(url.standardizedFileURL) && allowed(url.resolvingSymlinksInPath().standardizedFileURL)
    }

    private static func allowed(_ url: URL) -> Bool {
        let path = url.path
        guard !path.isEmpty, path != "/" else { return false }

        let home = URL(fileURLWithPath: RealHome.path).resolvingSymlinksInPath().standardizedFileURL.path
        if path == home { return false }

        let blocked = ["/System", "/usr", "/bin", "/sbin", "/Library/Apple", "/dev", "/etc", "/private/etc"]
        if blocked.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return false }
        let name = url.lastPathComponent
        if name == "Library" || name == "Applications" || name == "Users" { return false }
        if url.pathComponents.count < 3 { return false }

        let isApp = url.pathExtension.lowercased() == "app" || path.contains(".app/")
        let isLibraryItem = path.contains("/Library/")
        let isReceipt = path.hasPrefix("/private/var/db/receipts/") || path.hasPrefix("/Library/Receipts/")
        guard isApp || isLibraryItem || isReceipt else { return false }

        if path == "/private/var" || path.hasPrefix("/private/var/") {
            if !isApp && !isLibraryItem && !isReceipt { return false }
        }
        return true
    }
}
