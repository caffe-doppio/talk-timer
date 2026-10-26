import KeyboardShortcuts
import SwiftUI

// Raccourcis globaux : SPECS § 6.3 (valeurs par défaut) et § 7.4 (KeyboardShortcuts, conflits).
// Les valeurs initiales sont écrites une seule fois dans UserDefaults, au premier lancement :
// en changer une ne touche que les nouvelles installations. scripts/check-shortcuts.py les compare au brouillon.

extension KeyboardShortcuts.Name {
    static let nextBlock = Self("nextBlock", initial: Shortcut(.s, modifiers: [.control, .option]))
    static let previousBlock = Self("previousBlock", initial: Shortcut(.d, modifiers: [.control, .option]))  // à tester (§ 13)
    static let togglePause = Self("togglePause", initial: Shortcut(.c, modifiers: [.control, .option]))
    static let endSession = Self("endSession", initial: Shortcut(.x, modifiers: [.control, .option]))

    /// Les quatre, dans l'ordre du menu Session et des Réglages.
    static let session: [Self] = [.nextBlock, .previousBlock, .togglePause, .endSession]

    /// Nom de l'action, pour le message de conflit (§ 7.4).
    var title: String {
        switch self {
        case .nextBlock: String(localized: "Next")
        case .previousBlock: String(localized: "Back")
        case .togglePause: String(localized: "Pause / Resume")
        case .endSession: String(localized: "End")
        default: rawValue
        }
    }
}

/// Réglages (⌘,) : les quatre raccourcis, modifiables, et retour aux valeurs du § 6.3.
struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Next", name: .nextBlock)
                KeyboardShortcuts.Recorder("Back", name: .previousBlock)
                KeyboardShortcuts.Recorder("Pause / Resume", name: .togglePause)
                KeyboardShortcuts.Recorder("End", name: .endSession)
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Active during a session only, even when another app has the focus.")
                    .foregroundStyle(.secondary)
            }
            Button("Restore Defaults") { KeyboardShortcuts.reset(KeyboardShortcuts.Name.session) }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
