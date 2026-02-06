import SwiftUI
import ClayFeature

@main
struct ClayApp: App {
    init() {
#if DEBUG
        UncaughtExceptionLogger.install()
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Navigation") {
                Button("Base") { NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.base) }
                    .keyboardShortcut("1", modifiers: [.command])
                Button("Projects") { NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.projects) }
                    .keyboardShortcut("2", modifiers: [.command])
                Button("Partnerships") { NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.partnerships) }
                    .keyboardShortcut("3", modifiers: [.command])
                Button("Intel") { NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.intel) }
                    .keyboardShortcut("4", modifiers: [.command])
                Button("People") { NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.people) }
                    .keyboardShortcut("5", modifiers: [.command])
                Button("Settings") { NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.settings) }
                    .keyboardShortcut(",", modifiers: [.command])
            }
            CommandMenu("View") {
                Button("Toggle Base Focus Mode") {
                    NotificationCenter.default.post(name: .clayToggleBaseFocus, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])
            }
        }
    }
}
