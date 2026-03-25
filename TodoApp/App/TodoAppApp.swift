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
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
