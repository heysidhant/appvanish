import SwiftUI

@main
struct AppVanishApp: App {
    @State private var model = UninstallModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
        .defaultSize(width: 540, height: 500)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Choose App…") {
                    model.chooseApps()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
