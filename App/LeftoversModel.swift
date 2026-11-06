import AppKit
import Observation

@MainActor
@Observable
final class LeftoversModel {
    enum Phase: Equatable {
        case needsAccess
        case scanning
        case review
        case empty
        case removing
        case finished
    }

    var phase: Phase = .needsAccess
    var groups: [LeftoverGroup] = []
    var message: String?
    var movedCount = 0
    var failures: [RemovalFailure] = []

    private var homeURL: URL?
    private var started = false

    var selectedCount: Int { groups.filter(\.isSelected).count }

    var selectedByteSize: Int64 {
        groups.reduce(into: 0) { total, group in
            if group.isSelected { total += group.byteSize }
        }
    }

    func start() {
        guard !started else { return }
        started = true
        if let url = HomeAccess.restore() {
            homeURL = url
            rescan()
        }
    }

    func requestAccess() {
        message = nil
        do {
            guard let url = try HomeAccess.request() else { return }
            homeURL = url
            rescan()
        } catch {
            message = error.localizedDescription
        }
    }

    func forgetAccess() {
        HomeAccess.forget(homeURL)
        homeURL = nil
        groups = []
        message = nil
        phase = .needsAccess
    }

    func rescan() {
        guard homeURL != nil, phase != .scanning, phase != .removing else { return }
        phase = .scanning
        groups = []
        failures = []
        movedCount = 0
        message = nil
        let library = HomeAccess.home.appendingPathComponent("Library", isDirectory: true)
        let ownIdentifier = Bundle.main.bundleIdentifier

        Task {
            let found = await Task.detached(priority: .userInitiated) {
                let installed = InstalledApps.identifiers(in: [
                    URL(fileURLWithPath: "/Applications", isDirectory: true),
                    HomeAccess.home.appendingPathComponent("Applications", isDirectory: true),
                    URL(fileURLWithPath: "/System/Applications", isDirectory: true)
                ])
                let companies = Set(installed.map(LeftoverFinder.company(of:)))
                return LeftoverFinder.scan(library: library, ownIdentifier: ownIdentifier) { identifier in
                    LeftoverFinder.isLikelyInUse(identifier, installed: installed, companies: companies)
                        || !NSWorkspace.shared.urlsForApplications(withBundleIdentifier: identifier).isEmpty
                }
            }.value
            groups = found
            phase = found.isEmpty ? .empty : .review
        }
    }

    func setSelected(_ selected: Bool, id: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        groups[index].isSelected = selected
    }

    func setAllSelected(_ selected: Bool) {
        for index in groups.indices {
            groups[index].isSelected = selected
        }
    }

    func removeSelected() {
        let selected = groups.filter(\.isSelected)
        guard phase == .review, !selected.isEmpty else { return }
        phase = .removing
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                var moved = 0
                var failed: [RemovalFailure] = []
                for group in selected {
                    for url in group.urls {
                        do {
                            guard RemovalGuard.canTrash(url) else {
                                throw CocoaError(.fileWriteNoPermission)
                            }
                            try TrashMover.moveToTrash(url)
                            moved += 1
                        } catch {
                            failed.append(RemovalFailure(name: url.lastPathComponent, reason: error.localizedDescription))
                        }
                    }
                }
                return (moved, failed)
            }.value
            movedCount = result.0
            failures = result.1
            groups = []
            phase = .finished
        }
    }
}
