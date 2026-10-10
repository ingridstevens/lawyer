import SwiftUI

@main
struct NotALawyerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        Window("Not a Lawyer", id: "main") {
            ContentView()
                .environment(model)
                // Chats are saved a second after each change; make sure the last one is written on quit.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    model.saveChats()
                }
                .frame(minWidth: 780, minHeight: 560)
        }
        .defaultSize(width: 1080, height: 800)
        .commands {
            // Settings open as an overlay on the main window, not a separate window.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { model.settingsTab = .situation }
                    .keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {
                Button("New Chat") { model.newChat() }.keyboardShortcut("n")
                Button("New Ghost Chat") { model.newChat(ghost: true) }.keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandGroup(after: .newItem) {
                Button("Add Documents…") { model.sidebarSelection = .documents; model.importKind = nil; model.importingDocument = true }
                    .keyboardShortcut("o")
            }
        }
    }
}

/// Languages offered in the picker. Any language the model handles works; these are common ones.
let languageChoices: [String] = [
    "en", "de", "ar", "fa", "tr", "uk", "ru", "pl", "ro", "es", "fr", "it", "pt", "zh", "vi", "hi", "ku", "so", "ti",
]

func languageName(_ code: String) -> String {
    let own = Locale(identifier: code).localizedString(forLanguageCode: code) ?? code
    let english = Locale(identifier: "en").localizedString(forLanguageCode: code) ?? code
    return own == english ? own : "\(own) (\(english))"
}

extension Date {
    var lawDate: String { formatted(date: .long, time: .omitted) }
}
