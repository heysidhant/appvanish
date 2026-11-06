import Foundation

/// Everything found for one app that is no longer installed.
struct LeftoverGroup: Identifiable, Equatable, Sendable {
    var id: String
    var title: String
    var urls: [URL]
    var byteSize: Int64
    var isSelected = false
}

enum LeftoverFinder {
    /// Folders in the user's Library that hold per-app files named after a bundle identifier.
    static let folders = [
        "Application Support",
        "Caches",
        "HTTPStorages",
        "Logs",
        "Preferences",
        "Preferences/ByHost",
        "Saved Application State",
        "WebKit"
    ]

    private static let suffixes = [".savedState", ".binarycookies", ".plist"]
    private static let prefixes: Set<String> = [
        "ai", "app", "ch", "cn", "co", "com", "de", "dev", "eu", "fr", "in", "io", "jp",
        "me", "net", "nl", "org", "se", "sh", "tv", "uk", "us", "xyz"
    ]

    /// The bundle identifier in a file name, or nil when the name doesn't clearly contain one.
    static func bundleIdentifier(fromItemNamed name: String) -> String? {
        var candidate = name
        for suffix in suffixes where candidate.hasSuffix(suffix) {
            candidate = String(candidate.dropLast(suffix.count))
        }
        // ByHost preferences end with a device identifier: com.example.app.0000-1111.plist
        if let last = candidate.split(separator: ".").last, last.contains("-"), last.count >= 32 {
            candidate = String(candidate.dropLast(last.count + 1))
        }
        let parts = candidate.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3,
              parts.allSatisfy({ !$0.isEmpty }),
              prefixes.contains(parts[0].lowercased()),
              !candidate.contains(" ")
        else { return nil }
        return candidate
    }

    /// True when the identifier is an installed app, one of its helpers, or a parent of one.
    static func belongsToInstalledApp(_ identifier: String, installed: Set<String>) -> Bool {
        let id = identifier.lowercased()
        if installed.contains(id) { return true }
        let parts = id.split(separator: ".")
        if parts.count > 3 {
            for length in 3..<parts.count where installed.contains(parts[0..<length].joined(separator: ".")) {
                return true
            }
        }
        return installed.contains { $0.hasPrefix(id + ".") }
    }

    /// The company part of an identifier: com.example.app gives com.example.
    static func company(of identifier: String) -> String {
        identifier.lowercased().split(separator: ".").prefix(2).joined(separator: ".")
    }

    /// Developer tools with no app, whose files stay in use after any app is deleted.
    private static let toolPrefixes = [
        "com.android.", "com.firebase.", "com.install4j.", "com.segment.", "com.vercel.",
        "org.codehaus.", "org.cups.", "org.swift."
    ]

    /// True when an item is probably still used, so it should not be offered at all.
    static func isLikelyInUse(_ identifier: String, installed: Set<String>, companies: Set<String>) -> Bool {
        if belongsToInstalledApp(identifier, installed: installed) { return true }
        if companies.contains(company(of: identifier)) { return true }
        let id = identifier.lowercased()
        return toolPrefixes.contains { id.hasPrefix($0) }
    }

    /// A readable name: the last meaningful part of the identifier.
    static func title(for identifier: String) -> String {
        let parts = identifier.split(separator: ".").map(String.init)
        let meaningful = parts.dropFirst().last(where: LeftoverMatcher.isSpecific) ?? parts.last ?? identifier
        guard meaningful == meaningful.lowercased() else { return meaningful }
        return meaningful.prefix(1).uppercased() + meaningful.dropFirst()
    }

    /// Lists bundle-named items with no installed app. Nothing is selected: the person decides.
    static func scan(
        library: URL,
        ownIdentifier: String?,
        isInstalled: (String) -> Bool
    ) -> [LeftoverGroup] {
        let fileManager = FileManager.default
        var found: [String: [URL]] = [:]
        var names: [String: String] = [:]

        for folder in folders {
            let directory = library.appendingPathComponent(folder, isDirectory: true)
            guard let children = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }

            for child in children {
                guard let identifier = bundleIdentifier(fromItemNamed: child.lastPathComponent) else { continue }
                let key = identifier.lowercased()
                if key.hasPrefix("com.apple.") || key == ownIdentifier?.lowercased() { continue }
                if let own = ownIdentifier?.lowercased(), key.hasPrefix(own + ".") { continue }
                if isInstalled(identifier) { continue }
                guard RemovalGuard.canTrash(child) else { continue }
                found[key, default: []].append(child)
                if names[key] == nil { names[key] = identifier }
            }
        }

        // com.example.app.helper joins com.example.app when both were left behind.
        var merged: [String: [URL]] = [:]
        for key in found.keys.sorted(by: { $0.count < $1.count }) {
            let parent = merged.keys.first { key.hasPrefix($0 + ".") } ?? key
            merged[parent, default: []].append(contentsOf: found[key] ?? [])
        }

        return merged.map { key, urls in
            let identifier = names[key] ?? key
            return LeftoverGroup(
                id: identifier,
                title: title(for: identifier),
                urls: urls.sorted { $0.path < $1.path },
                byteSize: urls.reduce(0) { $0 + AppScanner.allocatedSize(of: $1) }
            )
        }
        .sorted { lhs, rhs in
            if lhs.byteSize != rhs.byteSize { return lhs.byteSize > rhs.byteSize }
            return lhs.id < rhs.id
        }
    }
}

enum InstalledApps {
    private static let helperFolders = [
        "Contents/Frameworks",
        "Contents/Helpers",
        "Contents/Library/LaunchServices",
        "Contents/Library/LoginItems",
        "Contents/PlugIns"
    ]

    /// Lowercased bundle identifiers of apps and the helpers inside them.
    static func identifiers(in directories: [URL]) -> Set<String> {
        var result = Set<String>()
        for directory in directories {
            collect(directory, depth: 0, into: &result)
        }
        return result
    }

    private static func collect(_ directory: URL, depth: Int, into result: inout Set<String>) {
        let fileManager = FileManager.default
        guard let children = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for child in children {
            if child.pathExtension.lowercased() == "app" {
                add(child, into: &result)
                for folder in helperFolders {
                    let helpers = (try? fileManager.contentsOfDirectory(
                        at: child.appendingPathComponent(folder, isDirectory: true),
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )) ?? []
                    helpers.forEach { add($0, into: &result) }
                }
                continue
            }
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            if depth < 2, values?.isDirectory == true, values?.isPackage != true {
                collect(child, depth: depth + 1, into: &result)
            }
        }
    }

    private static func add(_ url: URL, into result: inout Set<String>) {
        if let identifier = Bundle(url: url)?.bundleIdentifier?.lowercased() {
            result.insert(identifier)
        }
    }
}
