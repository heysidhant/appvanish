import AppKit
import Observation

struct RemovalFailure: Equatable, Identifiable, Sendable {
    var id: String { name + reason }
    var name: String
    var reason: String
}

@MainActor
@Observable
final class UninstallModel {
    enum Phase: Equatable {
        case ready
        case scanning
        case review
        case removing
        case finished
    }

    var phase: Phase = .ready
    var statusText = ""
    var items: [LeftoverItem] = []
    var notices: [String] = []
    var message: String?
    var messageIsError = false
    var movedCount = 0
    var failures: [RemovalFailure] = []
    var tossingTitles: [String] = []

    var selectedByteSize: Int64 {
        items.reduce(into: 0) { total, item in
            if item.isSelected { total += item.byteSize }
        }
    }

    var hasSelection: Bool {
        items.contains(where: \.isSelected)
    }

    func chooseApps() {
        guard phase == .ready || phase == .finished else { return }
        let panel = NSOpenPanel()
        panel.title = "Choose an app"
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }
        let urls = panel.urls
        Task { await scan(urls: urls) }
    }

    func scan(urls: [URL]) async {
        guard phase == .ready || phase == .finished else { return }
        phase = .scanning
        message = nil
        notices = []
        items = []
        failures = []
        movedCount = 0
        statusText = urls.count > 1 ? "Looking through \(urls.count) apps" : "Looking for leftover files"

        let roots = ScanRoots.standard
        let outcome = await Task.detached(priority: .userInitiated) {
            AppScanner.scan(urls: urls, roots: roots)
        }.value

        notices = outcome.notices
        items = outcome.items
        if items.isEmpty {
            phase = .ready
            message = outcome.notices.first ?? "No application was found in that drop."
            messageIsError = true
            return
        }
        message = nil
        phase = .review
    }

    func cancel() {
        guard phase == .review else { return }
        items = []
        notices = []
        phase = .ready
    }

    func setAllSelected(_ selected: Bool) {
        for index in items.indices {
            items[index].isSelected = selected
        }
    }

    func binding(for id: String) -> Bool {
        items.first(where: { $0.id == id })?.isSelected ?? false
    }

    func setSelected(_ selected: Bool, id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isSelected = selected
    }

    func removeSelected() async {
        guard phase == .review else { return }
        let selected = items.filter(\.isSelected)
        guard !selected.isEmpty else { return }

        tossingTitles = selected.map(\.title)
        phase = .removing
        let count = selected.count
        statusText = count == 1 ? "Tossing 1 file in" : "Tossing \(count) files in"
        let started = Date()
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let bundleIDs = Set(selected.compactMap { item -> String? in
            guard item.kind == .application || item.kind == .relatedApplication else { return nil }
            return item.bundleIdentifier
        })
        let stillRunning = await quitRunningApps(bundleIDs: bundleIDs)

        var moved = 0
        var failed: [RemovalFailure] = []
        let ordered = selected.sorted { $0.kind.sortRank < $1.kind.sortRank }
        for item in ordered {
            if let id = item.bundleIdentifier, stillRunning.contains(id) {
                failed.append(RemovalFailure(name: item.title, reason: "The app is still open. Quit it, then try again."))
                continue
            }
            guard RemovalGuard.canTrash(item.url) else {
                failed.append(RemovalFailure(name: item.title, reason: "That location is protected."))
                continue
            }
            do {
                let url = item.url
                try await Task.detached(priority: .userInitiated) {
                    try TrashMover.moveToTrash(url)
                }.value
                moved += 1
            } catch {
                failed.append(RemovalFailure(name: item.title, reason: error.localizedDescription))
            }
        }

        if !reduceMotion {
            let remaining = 0.9 - Date().timeIntervalSince(started)
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
        }
        movedCount = moved
        failures = failed
        phase = .finished
    }

    func reset() {
        items = []
        notices = []
        message = nil
        failures = []
        movedCount = 0
        tossingTitles = []
        phase = .ready
    }

    /// Asks apps to quit, so they can offer to save. Returns the ones still open: they are never force quit.
    private func quitRunningApps(bundleIDs: Set<String>) async -> Set<String> {
        let ownID = Bundle.main.bundleIdentifier
        var running: [NSRunningApplication] = []
        for bundleID in bundleIDs where bundleID != ownID {
            running.append(contentsOf: NSRunningApplication.runningApplications(withBundleIdentifier: bundleID))
        }
        let targets = running.filter { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard !targets.isEmpty else { return [] }
        targets.forEach { $0.terminate() }

        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            if targets.allSatisfy(\.isTerminated) { return [] }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return Set(targets.filter { !$0.isTerminated }.compactMap(\.bundleIdentifier))
    }
}
