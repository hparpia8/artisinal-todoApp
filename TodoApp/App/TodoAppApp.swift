import SwiftUI

@main
struct TodoAppApp: App {
    @AppStorage("colorScheme") private var colorSchemePreference: String = "auto"

    var resolvedColorScheme: ColorScheme? {
        AppColorScheme(rawValue: colorSchemePreference)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(resolvedColorScheme)
                .onOpenURL { url in
                    // todoapp://add — opened from the widget's "+" button
                    guard url.scheme == "todoapp", url.host == "add" else { return }
                    NSApp.activate(ignoringOtherApps: true)
                    NotificationCenter.default.post(name: .focusInput, object: nil)
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
