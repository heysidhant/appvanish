import SwiftUI

@main
struct AppVanishApp: App {
    #if APP_STORE
    @State private var model = LeftoversModel()
    #else
    @State private var model = UninstallModel()
    #endif

    var body: some Scene {
        WindowGroup {
            #if APP_STORE
            LeftoversView(model: model)
            #else
            ContentView(model: model)
            #endif
        }
        .defaultSize(width: 540, height: 500)
        .windowStyle(.hiddenTitleBar)
        .commands {
            #if APP_STORE
            CommandGroup(after: .newItem) {
                Button("Scan Again") {
                    model.rescan()
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Forget Home Folder Access") {
                    model.forgetAccess()
                }
            }
            #else
            CommandGroup(after: .newItem) {
                Button("Choose App…") {
                    model.chooseApps()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            #endif
        }
    }
}
