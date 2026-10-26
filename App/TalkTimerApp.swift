import SwiftUI

// App du Mac App Store (SPECS § 9) : une fenêtre par talk (§ 5).

@main
struct TalkTimerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: TalkDocument()) { file in
            PlannerView(document: file.$document)
                .onAppear { TalkDocument.detachMarkdownFiles() }
        }
        .commands { TalkCommands() }

        // Présentée au lancement, jamais restaurée ; Fenêtre › Accueil (⇧⌘1). Se ferme quand un talk s'ouvre.
        Window("Welcome", id: WelcomeView.id) { WelcomeView() }
            .windowResizability(.contentSize)
            .defaultLaunchBehavior(.presented)
            .restorationBehavior(.disabled)
            .keyboardShortcut("1", modifiers: [.command, .shift])

        Settings { SettingsView() }  // ⌘, (§ 5, § 7.4)
    }
}
