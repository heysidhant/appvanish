import AppKit

struct RemovalFailure: Equatable, Identifiable, Sendable {
    var id: String { name + reason }
    var name: String
    var reason: String
}

/// The user's real Home folder. In the sandbox, NSHomeDirectory() points at the app's container.
enum RealHome {
    static let path: String = {
        guard let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir else { return NSHomeDirectory() }
        return String(cString: dir)
    }()
}

enum TrashError: LocalizedError {
    case finderNotAllowed
    case cancelled
    case stillThere

    var errorDescription: String? {
        switch self {
        case .finderNotAllowed:
            return "Allow App Vanish to control Finder in System Settings > Privacy & Security > Automation."
        case .cancelled:
            return "You cancelled the password request, so it was left in place."
        case .stillThere:
            return "Finder could not move it to the Trash."
        }
    }
}

enum TrashMover {
    /// Moves to the Trash directly. For items that need an admin password, Finder asks for it.
    static func moveToTrash(_ url: URL) throws {
        #if APP_STORE
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        #else
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch where isPermissionError(error) {
            try askFinderToTrash(url)
        }
        #endif
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let codes: Set<Int> = [Int(EACCES), Int(EPERM)]
        var current: NSError? = error as NSError
        while let ns = current {
            if ns.domain == NSCocoaErrorDomain, ns.code == NSFileWriteNoPermissionError { return true }
            if ns.domain == NSPOSIXErrorDomain, codes.contains(ns.code) { return true }
            current = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }

    #if !APP_STORE
    /// Sent as an Apple event rather than a script, so a file name can never become code.
    private static func askFinderToTrash(_ url: URL) throws {
        let finder = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kAECoreSuite),
            eventID: AEEventID(kAEDelete),
            targetDescriptor: finder,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        guard let target = NSAppleEventDescriptor(
            descriptorType: DescType(typeFileURL),
            data: Data(url.absoluteString.utf8)
        ) else { throw TrashError.stillThere }
        event.setParam(target, forKeyword: AEKeyword(keyDirectObject))

        do {
            _ = try event.sendEvent(options: [.waitForReply], timeout: 120)
        } catch let error as NSError {
            switch error.code {
            case -1743: throw TrashError.finderNotAllowed
            case -128: throw TrashError.cancelled
            default: throw error
            }
        }
        if FileManager.default.fileExists(atPath: url.path) { throw TrashError.stillThere }
    }
    #endif
}
