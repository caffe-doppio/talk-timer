import AppKit
import SwiftUI
import TalkTimerCore
import UniformTypeIdentifiers

// Menus de l'app (SPECS § 5) : Fichier › Exporter en Markdown…, Aide › Politique de confidentialité.
// Le menu Session et les Réglages arrivent avec la barre et KeyboardShortcuts (§ 11, étape 6).

extension FocusedValues {
    /// Le talk de la fenêtre au premier plan, publié par `PlannerView` pour les menus.
    @Entry var talk: Talk?
}

struct TalkCommands: Commands {
    /// Publiée avec le dépôt à l'étape 8 (§ 14, P8) ; d'ici là, le lien mène à une page absente.
    static let privacyPolicy = URL(string: "https://github.com/caffe-doppio/talk-timer/blob/main/PRIVACY.md")!

    @FocusedValue(\.talk) private var talk
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export as Markdown…") { talk.map(exportMarkdown) }
                .disabled(talk == nil)
        }
        CommandGroup(replacing: .help) {
            Button("Privacy Policy") { openURL(Self.privacyPolicy) }
        }
    }

    /// Le panneau d'enregistrement donne l'accès en écriture au fichier choisi, sandbox compris (§ 8).
    private func exportMarkdown(_ talk: Talk) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.markdownText]
        let title = talk.title.isEmpty ? String(localized: "Untitled") : talk.title
        panel.nameFieldStringValue = title.replacingOccurrences(of: "/", with: "-") + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try talk.markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
