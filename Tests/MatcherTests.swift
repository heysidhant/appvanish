import XCTest
@testable import AppVanish

final class MatcherTests: XCTestCase {
    private let demo = MatchContext(
        bundleIdentifier: "com.example.demo",
        displayName: "Demo",
        executableName: "Demo"
    )

    func testBundleIdentifierDoesNotMatchLongerLookalike() {
        XCTAssertTrue(LeftoverMatcher.containsToken("com.example.demo.plist", token: "com.example.demo"))
        XCTAssertTrue(LeftoverMatcher.containsToken("com.example.demo.helper.plist", token: "com.example.demo"))
        XCTAssertFalse(LeftoverMatcher.containsToken("com.example.demonic.plist", token: "com.example.demo"))
    }

    func testDisplayNameMustBeExactAndSpecific() {
        XCTAssertTrue(LeftoverMatcher.shouldInclude(filename: "Demo", kind: .applicationSupport, context: demo))
        XCTAssertFalse(LeftoverMatcher.shouldInclude(filename: "Demonic", kind: .applicationSupport, context: demo))
        XCTAssertFalse(LeftoverMatcher.shouldInclude(filename: "Unrelated", kind: .caches, context: demo))

        let helper = MatchContext(bundleIdentifier: "com.example.helper", displayName: "Helper", executableName: "Helper")
        XCTAssertFalse(LeftoverMatcher.isSpecific("Helper"))
        XCTAssertFalse(LeftoverMatcher.shouldInclude(filename: "Helper", kind: .applicationSupport, context: helper))
        XCTAssertTrue(LeftoverMatcher.shouldInclude(filename: "com.example.helper", kind: .applicationSupport, context: helper))
    }

    func testCrashReportUsesNameBoundary() {
        XCTAssertTrue(LeftoverMatcher.shouldInclude(filename: "Demo_2024-01-01.ips", kind: .crashReport, context: demo))
        XCTAssertFalse(LeftoverMatcher.shouldInclude(filename: "Demonic_2024-01-01.ips", kind: .crashReport, context: demo))
    }

    func testGroupContainerAndLaunchAgentMatchBundleIdentifier() {
        XCTAssertTrue(LeftoverMatcher.shouldInclude(filename: "TEAMID.com.example.demo", kind: .groupContainer, context: demo))
        XCTAssertTrue(LeftoverMatcher.shouldInclude(filename: "com.example.demo.helper.plist", kind: .launchAgent, context: demo))
        XCTAssertFalse(LeftoverMatcher.shouldInclude(filename: "com.example.demonic.plist", kind: .launchAgent, context: demo))
    }

    func testExecutableOnlyMatchIsNotConfident() {
        let handler = MatchContext(bundleIdentifier: "com.example.urlhandler", displayName: "Demo URL Handler", executableName: "Demo")
        XCTAssertTrue(LeftoverMatcher.shouldInclude(filename: "Demo", kind: .applicationSupport, context: handler))
        XCTAssertFalse(LeftoverMatcher.isConfidentMatch(filename: "Demo", kind: .applicationSupport, context: handler))
        XCTAssertTrue(LeftoverMatcher.isConfidentMatch(filename: "Demo", kind: .applicationSupport, context: demo))
    }

    func testFilesOfAnotherInstalledAppAreNotConfident() {
        XCTAssertTrue(LeftoverMatcher.isConfidentMatch(filename: "com.example.demo.plist", kind: .preferences, context: demo))
        XCTAssertFalse(LeftoverMatcher.isConfidentMatch(
            filename: "com.example.demo.canary.plist",
            kind: .preferences,
            context: demo,
            otherBundleIdentifiers: ["com.example.demo.canary"]
        ))
    }

    func testPermissionErrorsAreRecognised() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        let wrapped = NSError(domain: NSCocoaErrorDomain, code: 1, userInfo: [NSUnderlyingErrorKey: underlying])
        XCTAssertTrue(TrashMover.isPermissionError(wrapped))
        XCTAssertTrue(TrashMover.isPermissionError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)))
        XCTAssertFalse(TrashMover.isPermissionError(NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError)))
    }
}
