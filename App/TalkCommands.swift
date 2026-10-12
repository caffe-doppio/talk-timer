import AppKit
import PDFKit
import SwiftUI
import TalkTimerCore
import UniformTypeIdentifiers

// Menus de l'app (SPECS § 5) : Fichier › Exporter en Markdown… et en PDF…, Imprimer…, Aide › Politique de confidentialité.
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
            Button("Export as PDF…") { talk.map(exportPDF) }
                .disabled(talk == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { talk.map(printTalk) }
                .keyboardShortcut("p")
                .disabled(talk == nil)
        }
        CommandGroup(replacing: .help) {
            Button("Privacy Policy") { openURL(Self.privacyPolicy) }
        }
    }

    private func exportMarkdown(_ talk: Talk) {
        guard let url = Self.saveURL(for: talk, type: .markdownText, extension: "md") else { return }
        do {
            try talk.markdown.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func exportPDF(_ talk: Talk) {
        guard let url = Self.saveURL(for: talk, type: .pdf, extension: "pdf") else { return }
        do {
            guard let data = TalkPrintView.pdf(talk) else { throw CocoaError(.fileWriteUnknown) }
            try data.write(to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    /// Imprime le PDF de l'export : une seule mise en page (§ 3.2). Entitlement `com.apple.security.print` (§ 8).
    private func printTalk(_ talk: Talk) {
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
