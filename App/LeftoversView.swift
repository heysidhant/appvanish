import SwiftUI

struct LeftoversView: View {
    @Bindable var model: LeftoversModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text("App Vanish")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishOnBlueSoft)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 6)

            ZStack {
                switch model.phase {
                case .needsAccess: accessState
                case .scanning: status("Looking for leftovers", lidOpen: true)
                case .review: reviewList
                case .empty: emptyState
                case .removing: status("Moving to Trash", lidOpen: true)
                case .finished: finishedState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: model.phase)
        }
        .frame(minWidth: 500, minHeight: 460)
        .background(.vanishBackground)
        .preferredColorScheme(.light)
        .onAppear(perform: model.start)
    }

    private var accessState: some View {
        VStack(spacing: 14) {
            BinMark(lidOpen: false, size: 150, showsApp: true)
                .shadow(color: Color.vanishInk.opacity(0.3), radius: 10, y: 8)
                .padding(.top, 36)
            Text("Find what deleted apps left behind")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishOnBlue)
            Text("Allow access to your Home folder so App Vanish can check your Library. Everything stays on your Mac.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Color.vanishOnBlueSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Choose Home Folder…", action: model.requestAccess)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(VanishButtonStyle())
                .padding(.top, 4)
            if let message = model.message {
                Text(message)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Color.vanishYellow)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
        }
        .padding(.horizontal, 28)
    }

    private func status(_ text: String, lidOpen: Bool) -> some View {
        VStack(spacing: 16) {
            BinMark(lidOpen: lidOpen, size: 150)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.vanishOnBlueSoft)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            BinMark(lidOpen: false, size: 150)
            Text("No leftovers found")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishOnBlue)
            Button("Scan Again", action: model.rescan)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(VanishButtonStyle())
        }
    }

    private var reviewList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                BinMark(lidOpen: false, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(summary)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.vanishOnBlue)
                    Text(ByteFormat.string(for: model.selectedByteSize))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.vanishOnBlueSoft)
                }
                Spacer()
                Button(allSelected ? "None" : "All") {
                    model.setAllSelected(!allSelected)
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishYellow)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(model.groups) { row($0) }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            Text("No app from these companies is installed. Some items may still belong to tools you use, so check each one.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Color.vanishOnBlueSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 4)

            HStack {
                Spacer()
                Button("Move to Trash", action: model.removeSelected)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(VanishButtonStyle())
                    .disabled(model.selectedCount == 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private func row(_ group: LeftoverGroup) -> some View {
        Toggle(isOn: Binding(
            get: { group.isSelected },
            set: { model.setSelected($0, id: group.id) }
        )) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.title)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.vanishInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(detail(for: group))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.vanishInk.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(ByteFormat.string(for: group.byteSize))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.vanishInk.opacity(0.62))
            }
        }
        .toggleStyle(BinToggleStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(group.urls)
            }
        }
        .help(group.urls.map { AppScanner.displayPath(for: $0) }.joined(separator: "\n"))
    }

    private var finishedState: some View {
        VStack(spacing: 14) {
            BinMark(lidOpen: false, size: 150)
            Text(finishedTitle)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishOnBlue)
                .multilineTextAlignment(.center)
            ForEach(model.failures.prefix(4)) { failure in
                Text("\(failure.name): \(failure.reason)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.vanishOnBlueSoft)
                    .frame(maxWidth: 380, alignment: .leading)
            }
            Button("Scan Again", action: model.rescan)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(VanishButtonStyle())
        }
        .padding(28)
    }

    private var allSelected: Bool {
        !model.groups.isEmpty && model.selectedCount == model.groups.count
    }

    private var summary: String {
        let count = model.groups.count
        let noun = count == 1 ? "1 possible leftover" : "\(count) possible leftovers"
        return model.selectedCount == 0 ? noun : "\(model.selectedCount) of \(count) selected"
    }

    private func detail(for group: LeftoverGroup) -> String {
        let places = group.urls.count == 1 ? "1 item" : "\(group.urls.count) items"
        return "\(group.id), \(places)"
    }

    private var finishedTitle: String {
        let moved = model.movedCount == 1 ? "1 item is in the Trash." : "\(model.movedCount) items are in the Trash."
        if model.failures.isEmpty { return moved }
        let left = model.failures.count == 1 ? "1 item was left in place." : "\(model.failures.count) items were left in place."
        return "\(moved) \(left)"
    }
}
