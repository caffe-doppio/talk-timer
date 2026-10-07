import AppKit
import SwiftUI

@main
struct TalkTimerApp: App {
    init() {
        // Lancé par `swift run`, sans bundle .app : sans ça, ni Dock ni focus clavier.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        WindowGroup("talk-timer") {
            Text("Planificateur : à venir (SPECS.md § 5)")
                .padding()
        }
    }
}
