import KeyboardShortcuts
import SwiftUI

// Raccourcis globaux : SPECS § 5 (Démarrer), § 6.3 (valeurs par défaut) et § 7.4 (KeyboardShortcuts, conflits).
// Les valeurs initiales sont écrites une seule fois dans UserDefaults, au premier lancement :
// en changer une ne touche que les nouvelles installations. scripts/check-shortcuts.py les compare au brouillon.

extension KeyboardShortcuts.Name {
    /// Hors session seulement, tant qu'un talk est ouvert : démarre le dernier talk actif (§ 5).
    static let startSession = Self("startSession", initial: Shortcut(.d, modifiers: [.control, .option]))
    static let nextBlock = Self("nextBlock", initial: Shortcut(.s, modifiers: [.control, .option]))
    static let previousBlock = Self("previousBlock", initial: Shortcut(.e, modifiers: [.control, .option]))
    static let togglePause = Self("togglePause", initial: Shortcut(.c, modifiers: [.control, .option]))
    static let endSession = Self("endSession", initial: Shortcut(.x, modifiers: [.control, .option]))

    /// Les quatre de la session, dans l'ordre du menu Session et des Réglages.
    static let session: [Self] = [.nextBlock, .previousBlock, .togglePause, .endSession]

    /// Nom de l'action, pour le message de conflit (§ 7.4).
    var title: String {
        switch self {
        case .startSession: String(localized: "Start")
        case .nextBlock: String(localized: "Next")
        case .previousBlock: String(localized: "Back")
        case .togglePause: String(localized: "Pause / Resume")
        case .endSession: String(localized: "End")
        default: rawValue
        }
    }
}

/// Réglages (⌘,) : les cinq raccourcis, modifiables, et retour aux valeurs par défaut.
struct SettingsView: View {
    var body: some View {
        Form {
            Section {
                KeyboardShortcuts.Recorder("Start", name: .startSession)
                KeyboardShortcuts.Recorder("Next", name: .nextBlock)
                KeyboardShortcuts.Recorder("Back", name: .previousBlock)
                KeyboardShortcuts.Recorder("Pause / Resume", name: .togglePause)
                KeyboardShortcuts.Recorder("End", name: .endSession)
            } header: {
                Text("Shortcuts")
            } footer: {
                Text("Start works while a talk is open, the others during a session only, even when another app has the focus.")
                    .foregroundStyle(.secondary)
            }
            Button("Restore Defaults") { KeyboardShortcuts.reset([.startSession] + KeyboardShortcuts.Name.session) }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
