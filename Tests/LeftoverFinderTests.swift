import XCTest
@testable import AppVanish

final class LeftoverFinderTests: XCTestCase {
    private func library() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Leftovers-\(UUID().uuidString)/Library", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root.deletingLastPathComponent()) }
        for folder in LeftoverFinder.folders {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(folder), withIntermediateDirectories: true)
        }
        return root
    }

    private func touch(_ library: URL, _ path: String) throws {
        try Data("x".utf8).write(to: library.appendingPathComponent(path))
    }

    func testReadsBundleIdentifiersFromFileNames() {
        XCTAssertEqual(LeftoverFinder.bundleIdentifier(fromItemNamed: "com.example.demo.plist"), "com.example.demo")
        XCTAssertEqual(LeftoverFinder.bundleIdentifier(fromItemNamed: "com.example.demo.savedState"), "com.example.demo")
        XCTAssertEqual(LeftoverFinder.bundleIdentifier(fromItemNamed: "com.example.demo"), "com.example.demo")
        XCTAssertEqual(
            LeftoverFinder.bundleIdentifier(fromItemNamed: "com.example.demo.01234567-89AB-CDEF-0123-456789ABCDEF.plist"),
            "com.example.demo"
        )
        XCTAssertNil(LeftoverFinder.bundleIdentifier(fromItemNamed: "Google"))
        XCTAssertNil(LeftoverFinder.bundleIdentifier(fromItemNamed: "notes.txt"))
        XCTAssertNil(LeftoverFinder.bundleIdentifier(fromItemNamed: "report.final.docx"))
        XCTAssertNil(LeftoverFinder.bundleIdentifier(fromItemNamed: "com.two"))
    }

    func testRecognisesInstalledAppsAndTheirHelpers() {
        let installed: Set<String> = ["com.example.demo", "com.other.suite.mail"]
        XCTAssertTrue(LeftoverFinder.belongsToInstalledApp("com.example.demo", installed: installed))
        XCTAssertTrue(LeftoverFinder.belongsToInstalledApp("com.example.Demo.helper", installed: installed))
        XCTAssertTrue(LeftoverFinder.belongsToInstalledApp("com.other.suite", installed: installed))
        XCTAssertFalse(LeftoverFinder.belongsToInstalledApp("com.example.demonic", installed: installed))
        XCTAssertFalse(LeftoverFinder.belongsToInstalledApp("com.gone.app", installed: installed))
    }

    func testFindsOnlyItemsWithNoInstalledAppAndSelectsNothing() throws {
        let lib = try library()
        try touch(lib, "Preferences/com.gone.app.plist")
        try FileManager.default.createDirectory(at: lib.appendingPathComponent("Caches/com.gone.app"), withIntermediateDirectories: true)
        try touch(lib, "Preferences/com.gone.app.helper.plist")
        try touch(lib, "Preferences/com.kept.app.plist")
        try touch(lib, "Preferences/com.apple.finder.plist")
        try touch(lib, "Preferences/com.heysidhant.self.plist")
        try FileManager.default.createDirectory(at: lib.appendingPathComponent("Application Support/Google"), withIntermediateDirectories: true)

        let groups = LeftoverFinder.scan(library: lib, ownIdentifier: "com.heysidhant.self") { $0 == "com.kept.app" }

        XCTAssertEqual(groups.map(\.id), ["com.gone.app"])
        XCTAssertEqual(groups.first?.urls.count, 3)
        XCTAssertEqual(groups.first?.isSelected, false)
    }

    func testTitlesAreReadable() {
        XCTAssertEqual(LeftoverFinder.title(for: "com.operasoftware.Opera"), "Opera")
        XCTAssertEqual(LeftoverFinder.title(for: "com.notchpixel.app"), "Notchpixel")
        XCTAssertEqual(LeftoverFinder.title(for: "com.example.tool.helper"), "Tool")
    }

    func testRemovalGuardAllowsLibraryItemsInRealHome() {
        let item = URL(fileURLWithPath: RealHome.path + "/Library/Preferences/com.gone.app.plist")
        XCTAssertTrue(RemovalGuard.canTrash(item))
        XCTAssertFalse(RemovalGuard.canTrash(URL(fileURLWithPath: RealHome.path)))
    }

    func testSkipsCompaniesWithAnInstalledAppAndKnownTools() {
        let installed: Set<String> = ["com.corel.coreldraw.2021"]
        let companies = Set(installed.map(LeftoverFinder.company(of:)))
        XCTAssertTrue(LeftoverFinder.isLikelyInUse("com.corel.coreldrawsuite.2021", installed: installed, companies: companies))
        XCTAssertTrue(LeftoverFinder.isLikelyInUse("org.swift.swiftpm", installed: installed, companies: companies))
        XCTAssertFalse(LeftoverFinder.isLikelyInUse("com.operasoftware.Opera", installed: installed, companies: companies))
    }
}
