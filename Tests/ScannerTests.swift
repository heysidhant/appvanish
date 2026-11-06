import XCTest
@testable import AppVanish

final class ScannerTests: XCTestCase {
    func testScanFindsLeftoversAndSkipsLookalikes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppVanish-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let app = root.appendingPathComponent("Applications/Demo.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>com.example.demo</string>
        <key>CFBundleName</key><string>Demo</string>
        <key>CFBundleExecutable</key><string>Demo</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        </dict></plist>
        """
        try Data(plist.utf8).write(to: app.appendingPathComponent("Contents/Info.plist"))

        let library = root.appendingPathComponent("Library", isDirectory: true)
        let support = library.appendingPathComponent("Application Support/Demo", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try Data("notes".utf8).write(to: support.appendingPathComponent("notes.txt"))
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Application Support/Unrelated"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Preferences"), withIntermediateDirectories: true)
        try Data("pref".utf8).write(to: library.appendingPathComponent("Preferences/com.example.demo.plist"))
        try Data("nope".utf8).write(to: library.appendingPathComponent("Preferences/com.example.demonic.plist"))
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Caches/com.example.demo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Saved Application State/com.example.demo.savedState"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Group Containers/TEAMID.com.example.demo"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: library.appendingPathComponent("LaunchAgents"), withIntermediateDirectories: true)
        try Data("agent".utf8).write(to: library.appendingPathComponent("LaunchAgents/com.example.demo.helper.plist"))
        try FileManager.default.createDirectory(at: library.appendingPathComponent("Logs/CrashReporter"), withIntermediateDirectories: true)
        try Data("crash".utf8).write(to: library.appendingPathComponent("Logs/CrashReporter/Demo_2024.ips"))

        let roots = ScanRoots(
            applicationDirectories: [root.appendingPathComponent("Applications")],
            libraryDirectories: [library],
            launchDaemonDirectories: [],
            receiptDirectories: []
        )
        let outcome = AppScanner.scan(urls: [app], roots: roots)
        let paths = outcome.items.map(\.displayPath)

        XCTAssertTrue(paths.contains { $0.hasSuffix("Demo.app") })
        XCTAssertTrue(paths.contains { $0.contains("Application Support/Demo") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("com.example.demo.plist") })
        XCTAssertTrue(paths.contains { $0.contains("Caches/com.example.demo") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("com.example.demo.savedState") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("TEAMID.com.example.demo") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("com.example.demo.helper.plist") })
        XCTAssertTrue(paths.contains { $0.hasSuffix("Demo_2024.ips") })
        XCTAssertFalse(paths.contains { $0.contains("Unrelated") })
        XCTAssertFalse(paths.contains { $0.contains("demonic") })
        XCTAssertTrue(outcome.notices.isEmpty)
    }

    func testSystemAppIsRefused() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppVanish-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("TextEdit.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>CFBundleIdentifier</key><string>com.apple.TextEdit</string>
        <key>CFBundleName</key><string>TextEdit</string>
        </dict></plist>
        """
        try Data(plist.utf8).write(to: app.appendingPathComponent("Contents/Info.plist"))

        let outcome = AppScanner.scan(urls: [app], roots: ScanRoots(applicationDirectories: [], libraryDirectories: [], launchDaemonDirectories: [], receiptDirectories: []))
        XCTAssertTrue(outcome.items.isEmpty)
        XCTAssertTrue(outcome.notices.contains(where: { $0.contains("Apple system app") }))
    }
}

final class RemovalGuardTests: XCTestCase {
    func testRefusesSystemLocationsAndAllowsAppBundles() {
        XCTAssertFalse(RemovalGuard.canTrash(URL(fileURLWithPath: "/")))
        XCTAssertFalse(RemovalGuard.canTrash(URL(fileURLWithPath: "/System/Applications/TextEdit.app")))
        XCTAssertFalse(RemovalGuard.canTrash(URL(fileURLWithPath: NSHomeDirectory())))
        XCTAssertFalse(RemovalGuard.canTrash(URL(fileURLWithPath: "/Applications")))
        XCTAssertTrue(RemovalGuard.canTrash(URL(fileURLWithPath: "/Applications/Demo.app")))
        XCTAssertTrue(RemovalGuard.canTrash(URL(fileURLWithPath: NSHomeDirectory() + "/Library/Preferences/com.example.demo.plist")))
    }

    private func makeApp(at url: URL, id: String, name: String) throws {
        try FileManager.default.createDirectory(at: url.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": name, "CFBundleExecutable": name]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Contents/Info.plist"))
    }

    func testRelatedAppsAndTheirFilesStartUnticked() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppVanish-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let main = apps.appendingPathComponent("Demo.app", isDirectory: true)
        try makeApp(at: main, id: "com.example.demo", name: "Demo")
        try makeApp(at: apps.appendingPathComponent("Demo Canary.app", isDirectory: true), id: "com.example.demo.canary", name: "Demo Canary")
        let prefs = root.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefs, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: prefs.appendingPathComponent("com.example.demo.plist"))
        try Data("b".utf8).write(to: prefs.appendingPathComponent("com.example.demo.canary.plist"))

        let roots = ScanRoots(applicationDirectories: [apps], libraryDirectories: [root.appendingPathComponent("Library")], launchDaemonDirectories: [], receiptDirectories: [])
        let items = AppScanner.scan(urls: [main], roots: roots).items

        XCTAssertEqual(items.first { $0.kind == .application }?.isSelected, true)
        XCTAssertEqual(items.first { $0.kind == .relatedApplication }?.isSelected, false)
        XCTAssertEqual(items.first { $0.title == "com.example.demo.plist" }?.isSelected, true)
        XCTAssertEqual(items.first { $0.title == "com.example.demo.canary.plist" }?.isSelected, false)
    }

    func testSecondCopyLeavesSharedFilesUnticked() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppVanish-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let apps = root.appendingPathComponent("Applications", isDirectory: true)
        let main = apps.appendingPathComponent("Demo.app", isDirectory: true)
        try makeApp(at: main, id: "com.example.demo", name: "Demo")
        try makeApp(at: apps.appendingPathComponent("Old/Demo.app", isDirectory: true), id: "com.example.demo", name: "Demo")
        let prefs = root.appendingPathComponent("Library/Preferences", isDirectory: true)
        try FileManager.default.createDirectory(at: prefs, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: prefs.appendingPathComponent("com.example.demo.plist"))

        let roots = ScanRoots(applicationDirectories: [apps], libraryDirectories: [root.appendingPathComponent("Library")], launchDaemonDirectories: [], receiptDirectories: [])
        let outcome = AppScanner.scan(urls: [main], roots: roots)

        XCTAssertEqual(outcome.items.first { $0.title == "com.example.demo.plist" }?.isSelected, false)
        XCTAssertTrue(outcome.notices.contains { $0.contains("Another copy") })
    }
}
