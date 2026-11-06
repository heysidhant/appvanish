import Foundation

struct AppIdentity: Equatable, Sendable {
    var bundleURL: URL
    var bundleIdentifier: String
    var displayName: String
    var executableName: String

    var context: MatchContext {
        MatchContext(bundleIdentifier: bundleIdentifier, displayName: displayName, executableName: executableName)
    }

    static func load(from url: URL) -> AppIdentity? {
        let plistURL = url.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              bundleIdentifier.contains("."),
              bundleIdentifier.count >= 5
        else { return nil }

        let folderName = url.deletingPathExtension().lastPathComponent
        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? folderName
        let executableName = (plist["CFBundleExecutable"] as? String) ?? folderName
        return AppIdentity(
            bundleURL: url,
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            executableName: executableName
        )
    }

    var isProtectedSystemApp: Bool {
        let identifier = bundleIdentifier.lowercased()
        if identifier == "com.apple" || identifier.hasPrefix("com.apple.") { return true }
        let path = bundleURL.resolvingSymlinksInPath().path
        return path == "/System" || path.hasPrefix("/System/")
    }
}

struct LeftoverItem: Identifiable, Equatable, Sendable {
    var id: String
    var url: URL
    var title: String
    var displayPath: String
    var byteSize: Int64
    var isSelected: Bool
    var kind: LeftoverKind
    var bundleIdentifier: String?
}

struct ScanRoots: Equatable, Sendable {
    var applicationDirectories: [URL]
    var libraryDirectories: [URL]
    var launchDaemonDirectories: [URL]
    var receiptDirectories: [URL]

    static var standard: ScanRoots {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return ScanRoots(
            applicationDirectories: [
                URL(fileURLWithPath: "/Applications", isDirectory: true),
                home.appendingPathComponent("Applications", isDirectory: true)
            ],
            libraryDirectories: [
                home.appendingPathComponent("Library", isDirectory: true),
                URL(fileURLWithPath: "/Library", isDirectory: true)
            ],
            launchDaemonDirectories: [
                URL(fileURLWithPath: "/Library/LaunchDaemons", isDirectory: true),
                URL(fileURLWithPath: "/Library/PrivilegedHelperTools", isDirectory: true)
            ],
            receiptDirectories: [
                URL(fileURLWithPath: "/Library/Receipts", isDirectory: true),
                URL(fileURLWithPath: "/private/var/db/receipts", isDirectory: true)
            ]
        )
    }
}

struct ScanOutcome: Equatable, Sendable {
    var items: [LeftoverItem]
    var notices: [String]
}

enum AppScanner {
    private static let libraryFolders: [(String, LeftoverKind)] = [
        ("Application Support", .applicationSupport),
        ("Preferences", .preferences),
        ("Preferences/ByHost", .byHost),
        ("Caches", .caches),
        ("Logs", .logs),
        ("Logs/CrashReporter", .crashReport),
        ("Saved Application State", .savedState),
        ("Containers", .container),
        ("Application Scripts", .applicationScripts),
        ("HTTPStorages", .httpStorage),
        ("WebKit", .webKit),
        ("Cookies", .cookies),
        ("LaunchAgents", .launchAgent),
        ("Group Containers", .groupContainer),
        ("Internet Plug-Ins", .plugin),
        ("PreferencePanes", .plugin),
        ("Input Methods", .plugin),
        ("Screen Savers", .plugin),
        ("Services", .plugin)
    ]

    static func scan(urls: [URL], roots: ScanRoots) -> ScanOutcome {
        var items: [LeftoverItem] = []
        var notices: [String] = []
        var seen = Set<String>()

        func add(_ item: LeftoverItem) {
            guard RemovalGuard.canTrash(item.url) else { return }
            let key = canonical(item.url)
            guard seen.insert(key).inserted else { return }
            items.append(item)
        }

        let resolvedApps = urls.map(resolve)
        if resolvedApps.isEmpty {
            return ScanOutcome(items: [], notices: ["Drop a Mac application."])
        }

        for url in resolvedApps {
            guard url.pathExtension.lowercased() == "app" else {
                notices.append("\(url.lastPathComponent) is not an application.")
                continue
            }
            guard let identity = AppIdentity.load(from: url) else {
                notices.append("\(url.lastPathComponent) has no bundle identifier App Vanish can follow.")
                continue
            }
            if identity.isProtectedSystemApp {
                notices.append("\(identity.displayName) is an Apple system app, so it was left in place.")
                continue
            }

            add(makeItem(
                url: identity.bundleURL,
                title: identity.displayName,
                kind: .application,
                bundleIdentifier: identity.bundleIdentifier
            ))

            let related = relatedApplications(of: identity, roots: roots)
            let ownID = identity.bundleIdentifier.lowercased()
            let hasOtherCopy = related.contains { $0.bundleIdentifier.lowercased() == ownID }
            let otherIDs = Set(related.map(\.bundleIdentifier).filter { $0.lowercased() != ownID })
            if hasOtherCopy {
                notices.append("Another copy of \(identity.displayName) is installed. It shares these files, so they start unticked.")
            }

            for app in related {
                add(makeItem(
                    url: app.bundleURL,
                    title: app.displayName,
                    kind: .relatedApplication,
                    bundleIdentifier: app.bundleIdentifier,
                    isSelected: false
                ))
            }

            for library in roots.libraryDirectories {
                for (folder, kind) in libraryFolders {
                    collect(
                        directory: library.appendingPathComponent(folder, isDirectory: true),
                        kind: kind,
                        identity: identity,
                        otherIDs: otherIDs,
                        sharedWithOtherCopy: hasOtherCopy,
                        add: add
                    )
                }
            }
            for directory in roots.launchDaemonDirectories {
                collect(directory: directory, kind: .launchDaemon, identity: identity, otherIDs: otherIDs, sharedWithOtherCopy: hasOtherCopy, add: add)
            }
            for directory in roots.receiptDirectories {
                collect(directory: directory, kind: .receipt, identity: identity, otherIDs: otherIDs, sharedWithOtherCopy: hasOtherCopy, add: add)
            }
        }

        items.sort { lhs, rhs in
            if lhs.kind.sortRank != rhs.kind.sortRank { return lhs.kind.sortRank < rhs.kind.sortRank }
            if lhs.byteSize != rhs.byteSize { return lhs.byteSize > rhs.byteSize }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return ScanOutcome(items: items, notices: notices)
    }

    private static func collect(
        directory: URL,
        kind: LeftoverKind,
        identity: AppIdentity,
        otherIDs: Set<String>,
        sharedWithOtherCopy: Bool,
        add: (LeftoverItem) -> Void
    ) {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children {
            guard LeftoverMatcher.shouldInclude(
                filename: child.lastPathComponent,
                kind: kind,
                context: identity.context
            ) else { continue }
            let confident = LeftoverMatcher.isConfidentMatch(
                filename: child.lastPathComponent,
                kind: kind,
                context: identity.context,
                otherBundleIdentifiers: otherIDs
            )
            add(makeItem(
                url: child,
                title: child.lastPathComponent,
                kind: kind,
                bundleIdentifier: identity.bundleIdentifier,
                isSelected: confident && !sharedWithOtherCopy
            ))
        }
    }

    private static func relatedApplications(of identity: AppIdentity, roots: ScanRoots) -> [AppIdentity] {
        let prefix = identity.bundleIdentifier.lowercased() + "."
        let ownPath = canonical(identity.bundleURL)
        var related: [AppIdentity] = []
        for directory in roots.applicationDirectories {
            for appURL in applicationBundles(in: directory, depth: 0) {
                guard canonical(appURL) != ownPath else { continue }
                guard let other = AppIdentity.load(from: appURL), !other.isProtectedSystemApp else { continue }
                let otherID = other.bundleIdentifier.lowercased()
                if otherID == identity.bundleIdentifier.lowercased() || otherID.hasPrefix(prefix) {
                    related.append(other)
                }
            }
        }
        return related
    }

    private static func applicationBundles(in directory: URL, depth: Int) -> [URL] {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var apps: [URL] = []
        for child in children {
            if child.pathExtension.lowercased() == "app" {
                apps.append(child)
                continue
            }
            guard depth == 0 else { continue }
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let isPackage = (try? child.resourceValues(forKeys: [.isPackageKey]).isPackage) ?? false
            if isDirectory && !isPackage {
                apps.append(contentsOf: applicationBundles(in: child, depth: 1))
            }
        }
        return apps
    }

    private static func makeItem(
        url: URL,
        title: String,
        kind: LeftoverKind,
        bundleIdentifier: String?,
        isSelected: Bool = true
    ) -> LeftoverItem {
        LeftoverItem(
            id: canonical(url),
            url: url,
            title: title,
            displayPath: displayPath(for: url),
            byteSize: allocatedSize(of: url),
            isSelected: isSelected,
            kind: kind,
            bundleIdentifier: bundleIdentifier
        )
    }

    static func displayPath(for url: URL) -> String {
        let home = RealHome.path
        let path = url.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    static func allocatedSize(of url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        if let values = try? url.resourceValues(forKeys: keys), values.isDirectory != true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: []
        ) else { return 0 }

        var total: Int64 = 0
        for case let file as URL in enumerator {
            guard let values = try? file.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    private static func resolve(_ url: URL) -> URL {
        if let alias = try? URL(resolvingAliasFileAt: url, options: []) {
            return alias.standardizedFileURL
        }
        return url.standardizedFileURL
    }

    private static func canonical(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
