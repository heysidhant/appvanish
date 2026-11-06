import AppKit

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
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch where isPermissionError(error) {
            try askFinderToTrash(url)
        }
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
}
