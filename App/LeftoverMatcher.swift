import Foundation

enum LeftoverKind: String, Equatable, Sendable {
    case application
    case relatedApplication
    case applicationSupport
    case preferences
    case byHost
    case caches
    case logs
    case crashReport
    case savedState
    case container
    case applicationScripts
    case httpStorage
    case webKit
    case cookies
    case launchAgent
    case launchDaemon
    case groupContainer
    case receipt
    case plugin

    var sortRank: Int {
        switch self {
        case .application: return 0
        case .relatedApplication: return 1
        default: return 2
        }
    }
}

struct MatchContext: Equatable, Sendable {
    var bundleIdentifier: String
    var displayName: String
    var executableName: String
}

enum LeftoverMatcher {
    private static let genericNames: Set<String> = [
        "app", "application", "applications", "helper", "agent", "service",
        "plugin", "launcher", "installer", "uninstaller", "updater", "update",
        "setup", "main", "mac", "macos", "apple", "system", "library",
        "desktop", "default", "common", "shared", "support", "cache",
        "caches", "preferences", "logs", "log", "python", "node", "java",
        "ruby", "perl", "php", "electron", "crashreporter", "pro", "dev",
        "beta", "test", "the", "new", "old"
    ]

    static func isSpecific(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.contains(where: \.isLetter) else { return false }
        return !genericNames.contains(trimmed.lowercased())
    }

    static func containsToken(_ filename: String, token: String) -> Bool {
        let haystack = filename.lowercased()
        let needle = token.lowercased()
        guard needle.count >= 3 else { return false }
        var start = haystack.startIndex
        while start < haystack.endIndex, let range = haystack.range(of: needle, range: start..<haystack.endIndex) {
            let beforeOK = range.lowerBound == haystack.startIndex || !isTokenCharacter(haystack[haystack.index(before: range.lowerBound)])
            let afterOK = range.upperBound == haystack.endIndex || !isTokenCharacter(haystack[range.upperBound])
            if beforeOK && afterOK { return true }
            start = range.upperBound
        }
        return false
    }

    static func shouldInclude(filename: String, kind: LeftoverKind, context: MatchContext) -> Bool {
        switch kind {
        case .application, .relatedApplication:
            return false
        case .applicationSupport, .caches, .logs, .plugin:
            if namesMatch(filename, context.bundleIdentifier) { return true }
            if isSpecific(context.displayName), namesMatch(filename, context.displayName) { return true }
            if isSpecific(context.executableName), namesMatch(filename, context.executableName) { return true }
            return false
        case .preferences, .byHost, .savedState, .container, .applicationScripts, .httpStorage, .webKit, .cookies, .launchAgent, .launchDaemon, .groupContainer, .receipt:
            return containsToken(filename, token: context.bundleIdentifier)
        case .crashReport:
            if containsToken(filename, token: context.bundleIdentifier) { return true }
            if isSpecific(context.executableName), containsToken(filename, token: context.executableName) { return true }
            if isSpecific(context.displayName), containsToken(filename, token: context.displayName) { return true }
            return false
        }
    }

    /// False when a file might belong to something else, so it starts unticked and the person decides.
    static func isConfidentMatch(
        filename: String,
        kind: LeftoverKind,
        context: MatchContext,
        otherBundleIdentifiers: Set<String> = []
    ) -> Bool {
        if otherBundleIdentifiers.contains(where: { containsToken(filename, token: $0) }) { return false }
        switch kind {
        case .applicationSupport, .caches, .logs, .plugin:
            if namesMatch(filename, context.bundleIdentifier) { return true }
            return isSpecific(context.displayName) && namesMatch(filename, context.displayName)
        case .crashReport:
            if containsToken(filename, token: context.bundleIdentifier) { return true }
            return isSpecific(context.displayName) && containsToken(filename, token: context.displayName)
        default:
            return true
        }
    }

    private static func namesMatch(_ filename: String, _ name: String) -> Bool {
        filename.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func isTokenCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
