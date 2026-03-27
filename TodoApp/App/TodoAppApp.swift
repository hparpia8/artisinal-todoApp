import SwiftUI
import WidgetKit

@main
struct TodoAppApp: App {
    @StateObject private var store = TodoStore()
    @AppStorage("colorScheme") private var colorSchemePreference: String = "auto"

    var resolvedColorScheme: ColorScheme? {
        AppColorScheme(rawValue: colorSchemePreference)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(resolvedColorScheme)
                .onOpenURL { url in
                    switch (url.scheme, url.host) {
                    case ("todoapp", "add"):
                        // Opened from the widget's "+" button
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .focusInput, object: nil)
                    case ("artisanaltodo", "refresh"):
                        // Triggered by the MCP server after writing todos.json
                        store.load()
                        WidgetCenter.shared.reloadAllTimelines()
                    default:
                        break
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

extension Notification.Name {
    static let focusInput = Notification.Name("focusInput")
}
