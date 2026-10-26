import AppKit
import KeyboardShortcuts
import PDFKit
import SwiftUI
import TalkTimerCore
import UniformTypeIdentifiers

// Menus de l'app (SPECS § 5) : Fichier › Exporter en Markdown… et en PDF…, Imprimer…, Session, Aide › Politique de confidentialité.

extension FocusedValues {
    /// Le talk de la fenêtre au premier plan, publié par `PlannerView` pour les menus. Une liaison :
    /// Édition › Ajouter un bloc modifie le document, et passe par ⌘Z comme le bouton de la barre d'outils.
    @Entry var talk: Binding<Talk>?
}

struct TalkCommands: Commands {
    /// Publiée avec le dépôt à l'étape 8 (§ 14, P8) ; d'ici là, le lien mène à une page absente.
    static let privacyPolicy = URL(string: "https://github.com/caffe-doppio/talk-timer/blob/main/PRIVACY.md")!

    @FocusedBinding(\.talk) private var talk
    @Environment(\.openURL) private var openURL

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Export as Markdown…") { talk.map(Self.exportMarkdown) }
                .disabled(talk == nil)
            Button("Export as PDF…") { talk.map(Self.exportPDF) }
                .disabled(talk == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { talk.map(Self.printTalk) }
                .keyboardShortcut("p")
                .disabled(talk == nil)
        }
        // Édition › Ajouter un bloc : le bouton + de la barre d'outils, qui peut être masquée (§ 5).
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Add Block", systemImage: "plus") { _ = talk?.addBlock(title: String(localized: "New block")) }
                .disabled((talk?.margin ?? 0) < 1)
        }
        // Session (§ 5) : chaque action de la barre, avec son raccourci global affiché, tel que réglé (§ 7.4).
        // `globalKeyboardShortcut` montre la combinaison sans la déclencher : le raccourci global passe avant.
        CommandMenu("Session") {
            let live = Live.shared
            Button("Start", systemImage: "play.fill") { live.startLastActive() }  // la fenêtre au premier plan, dernier planificateur actif
                .globalKeyboardShortcut(.startSession)
                .disabled(talk?.blocks.isEmpty ?? true || live.session != nil)  // comme le bouton du planificateur
            Divider()
            Group {
                Button("Next", systemImage: "forward.end") { live.next() }
                    .globalKeyboardShortcut(.nextBlock)
                Button("Back", systemImage: "backward.end") { live.back() }
                    .globalKeyboardShortcut(.previousBlock)
                Button("Pause / Resume", systemImage: "playpause") { live.togglePause() }
                    .globalKeyboardShortcut(.togglePause)
                Divider()
                Button("End", systemImage: "flag.pattern.checkered.2.crossed") { live.finish() }
                    .globalKeyboardShortcut(.endSession)
            }
            .disabled(live.session == nil)
        }
        CommandGroup(replacing: .help) {
            Button("Privacy Policy") { openURL(Self.privacyPolicy) }
        }
    }

    static func exportMarkdown(_ talk: Talk) {
        guard let url = Self.saveURL(for: talk, type: .markdownText, extension: "md") else { return }
        do {
            try talk.markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    static func exportPDF(_ talk: Talk) {
        guard let url = Self.saveURL(for: talk, type: .pdf, extension: "pdf") else { return }
        do {
            guard let data = TalkPrintView.pdf(talk) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Imprime le PDF de l'export : une seule mise en page (§ 3.2). Entitlement `com.apple.security.print` (§ 8).
    static func printTalk(_ talk: Talk) {
        guard let data = TalkPrintView.pdf(talk), let document = PDFDocument(data: data) else { return }
        document.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleNone, autoRotate: false)?.run()
    }

    /// Le panneau d'enregistrement donne l'accès en écriture au fichier choisi, sandbox compris (§ 8).
    private static func saveURL(for talk: Talk, type: UTType, extension ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        let title = talk.title.isEmpty ? String(localized: "Untitled") : talk.title
        panel.nameFieldStringValue = title.replacingOccurrences(of: "/", with: "-") + "." + ext
        return panel.runModal() == .OK ? panel.url : nil
    }
}
