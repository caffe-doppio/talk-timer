import SwiftUI
import TalkTimerCore  // lien avec le paquet vérifié dès la compilation (SPECS § 9)

// App du Mac App Store. Étape 4 (SPECS § 11) : squelette signé et sandboxé ; DocumentGroup à l'étape 5.

@main
struct TalkTimerApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Planner: coming soon")
                .padding()
        }
    }
}
