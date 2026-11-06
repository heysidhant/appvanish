import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: UninstallModel
    @State private var isTargeted = false
    @State private var isHovering = false
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
                case .ready:
                    dropZone.transition(.opacity)
                case .scanning:
                    scanningState.transition(.opacity.combined(with: .scale(scale: 0.96)))
                case .review:
                    reviewList.transition(.opacity.combined(with: .move(edge: .bottom)))
                case .removing:
                    tossingState.transition(.opacity)
                case .finished:
                    finishedState.transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: model.phase)
        }
        .frame(minWidth: 500, minHeight: 460)
        .background(.vanishBackground)
        .preferredColorScheme(.light)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Button(action: model.chooseApps) {
                VStack(spacing: 18) {
                    BinMark(lidOpen: isTargeted || isHovering, size: 178, showsApp: true)
                        .shadow(color: Color.vanishInk.opacity(0.3), radius: isTargeted ? 18 : 10, y: 8)
                        .scaleEffect(isTargeted ? 1.04 : 1)
                        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.7), value: isTargeted)
                    VStack(spacing: 4) {
                        Text("Drop an app in the bin")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.vanishOnBlue)
                        Text("or click to choose")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Color.vanishOnBlueSoft)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .accessibilityLabel("Drop an app in the bin")

            if let message = model.message {
                Text(message)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(model.messageIsError ? Color.vanishYellow : Color.vanishOnBlueSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.bottom, 24)
            }
        }
        .padding(.horizontal, 28)
    }

    private var scanningState: some View {
        VStack(spacing: 16) {
            BinMark(lidOpen: true, size: 150)
                .modifier(RummageEffect(active: !reduceMotion))
            Text(model.statusText)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.vanishOnBlueSoft)
        }
    }

    private var reviewList: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                BinMark(lidOpen: false, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(foundLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.vanishOnBlue)
                    Text(ByteFormat.string(for: model.selectedByteSize))
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Color.vanishOnBlueSoft)
                }
                Spacer()
                Button(model.hasSelection && model.items.allSatisfy(\.isSelected) ? "None" : "All") {
                    let turnOn = !model.items.allSatisfy(\.isSelected)
                    withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                        model.setAllSelected(turnOn)
                    }
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
                    ForEach(Array(model.items.enumerated()), id: \.element.id) { index, item in
                        fileRow(item, index: index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            if !model.notices.isEmpty {
                Text(model.notices.joined(separator: " "))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.vanishOnBlueSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }

            HStack {
                Button("Cancel", action: model.cancel)
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.vanishOnBlueSoft)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Spacer()
                Button("Move to Trash") {
                    Task { await model.removeSelected() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(VanishButtonStyle())
                .disabled(!model.hasSelection)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private func fileRow(_ item: LeftoverItem, index: Int) -> some View {
        Toggle(isOn: selection(for: item.id)) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.vanishInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(item.displayPath)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Color.vanishInk.opacity(0.62))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 8)
                Text(ByteFormat.string(for: item.byteSize))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.vanishInk.opacity(0.62))
            }
        }
        .toggleStyle(BinToggleStyle())
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
        }
        .modifier(RowAppear(index: index, enabled: !reduceMotion))
    }

    private var tossingState: some View {
        TossingView(titles: model.tossingTitles, caption: model.statusText, reduceMotion: reduceMotion)
    }

    private var finishedState: some View {
        FinishedView(
            movedCount: model.movedCount,
            failures: model.failures,
            title: finishedTitle,
            reduceMotion: reduceMotion,
            again: model.reset
        )
    }

    private var foundLabel: String {
        let count = model.items.count
        let selected = model.items.filter(\.isSelected).count
        if selected == count {
            return count == 1 ? "1 file" : "\(count) files"
        }
        return "\(selected) of \(count)"
    }

    private var finishedTitle: String {
        let moved: String
        switch model.movedCount {
        case 0: moved = "Nothing reached the Trash."
        case 1: moved = "1 file is in the Trash."
        default: moved = "\(model.movedCount) files are in the Trash."
        }
        if model.failures.isEmpty { return moved }
        let left = model.failures.count == 1 ? "1 file is still in place." : "\(model.failures.count) files are still in place."
        return "\(moved) \(left)"
    }

    private func selection(for id: String) -> Binding<Bool> {
        Binding(
            get: { model.binding(for: id) },
            set: { newValue in
                withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.75)) {
                    model.setSelected(newValue, id: id)
                }
            }
        )
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard model.phase == .ready || model.phase == .finished else { return false }
        let supported = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !supported.isEmpty else { return false }
        Task {
            var urls: [URL] = []
            for provider in supported {
                if let url = await Self.loadURL(from: provider) {
                    urls.append(url)
                }
            }
            await model.scan(urls: urls)
        }
        return true
    }

    private static func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            let gate = ResumeOnce()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                gate.resume {
                    continuation.resume(returning: url(from: item))
                }
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data { return URL(dataRepresentation: data, relativeTo: nil) }
        if let text = item as? String { return URL(string: text) }
        return nil
    }
}

private struct TossingView: View {
    let titles: [String]
    let caption: String
    let reduceMotion: Bool
    @State private var dropped = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                VStack {
                    Spacer()
                    BinMark(lidOpen: !dropped, size: 150)
                        .scaleEffect(dropped ? 1.05 : 1)
                        .shadow(color: Color.vanishInk.opacity(0.3), radius: 10, y: 8)
                }
                VStack(spacing: 8) {
                    ForEach(Array(titles.prefix(4).enumerated()), id: \.offset) { index, title in
                        Text(title)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white))
                            .foregroundStyle(Color.vanishInk)
                            .offset(y: dropped ? 120 : CGFloat(index) * -6)
                            .scaleEffect(dropped ? 0.35 : 1)
                            .opacity(dropped ? 0 : 1)
                            .animation(
                                reduceMotion ? nil : .easeIn(duration: 0.55).delay(Double(index) * 0.07),
                                value: dropped
                            )
                    }
                    Spacer().frame(height: 120)
                }
            }
            .frame(height: 280)
            Text(caption)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Color.vanishOnBlueSoft)
        }
        .onAppear {
            if reduceMotion {
                dropped = true
            } else {
                withAnimation(.easeIn(duration: 0.15)) {
                    dropped = true
                }
            }
        }
    }
}

private struct FinishedView: View {
    let movedCount: Int
    let failures: [RemovalFailure]
    let title: String
    let reduceMotion: Bool
    let again: () -> Void
    @State private var settled = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                BinMark(lidOpen: movedCount == 0 || !settled, size: 156)
                    .scaleEffect(settled ? 1 : 0.92)
                    .shadow(color: Color.vanishInk.opacity(0.3), radius: 10, y: 8)
                if movedCount > 0 && settled {
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.vanishInk)
                        .padding(10)
                        .background(Circle().fill(.vanishApp))
                        .offset(x: 58, y: 48)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.7), value: settled)

            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.vanishOnBlue)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            if !failures.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(failures) { failure in
                        Text("\(failure.name): \(failure.reason)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Color.vanishOnBlueSoft)
                    }
                }
                .frame(maxWidth: 380, alignment: .leading)
            }

            Button("Drop another app", action: again)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(VanishButtonStyle())
                .padding(.top, 4)
        }
        .padding(28)
        .onAppear {
            if reduceMotion {
                settled = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(0.05)) {
                    settled = true
                }
            }
        }
    }
}

private struct RummageEffect: ViewModifier {
    var active: Bool
    @State private var wobble = false

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(active && wobble ? 2.5 : (active ? -2.5 : 0)))
            .animation(active ? .easeInOut(duration: 0.38).repeatForever(autoreverses: true) : nil, value: wobble)
            .onAppear { wobble = active }
    }
}

private struct RowAppear: ViewModifier {
    var index: Int
    var enabled: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown || !enabled ? 1 : 0)
            .offset(y: shown || !enabled ? 0 : 12)
            .onAppear {
                guard enabled else {
                    shown = true
                    return
                }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82).delay(Double(index) * 0.045)) {
                    shown = true
                }
            }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        body()
    }
}
