import AppKit
import SwiftUI
import TalkTimerCore
import UniformTypeIdentifiers

// Fichier de talk (SPECS § 3, § 5). `nonisolated` : l'app est isolée au MainActor par défaut,
// mais `DocumentGroup` lit et écrit les documents hors du thread principal.

extension UTType {
    /// Déclaré dans Info.plist (UTExportedTypeDeclarations), conforme à `public.json`.
    nonisolated static let talk = UTType(exportedAs: "io.github.caffe-doppio.talk-timer.talk", conformingTo: .json)
    /// Lu, jamais écrit (rang `Alternate`) : talk-timer ne devient jamais l'app par défaut des `.md` (§ 5).
    nonisolated static let markdownText = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

/// Un talk ouvert dans une fenêtre. Lit `.talk` et `.md`, n'écrit que `.talk` : un `.md` n'est jamais réécrit (§ 3.1, § 5).
nonisolated struct TalkDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.talk, .markdownText]
    static let writableContentTypes: [UTType] = [.talk]

    var talk: Talk

    /// Nouveau talk : 30 min, un premier bloc de 5 min. Un talk sans bloc serait refusé au chargement (§ 3).
    init(talk: Talk = Talk(title: "", totalMinutes: 30, blocks: [Block(title: String(localized: "Introduction"), minutes: 5)])) {
        self.talk = talk
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        if configuration.contentType.conforms(to: .talk) {
            talk = try Talk.load(from: data)
        } else {
            guard let text = String(bytes: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
            talk = try Talk(markdown: text)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Garde-fou : l'enregistrement automatique écrit sur place même hors de `writableContentTypes`.
        // Vu le 2026-10-12 : un `.md` ouvert a été réécrit en JSON. Mieux vaut une erreur qu'un `.md` perdu.
        guard configuration.contentType.conforms(to: .talk) else { throw CocoaError(.featureUnsupported) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]  // diff lisible, ordre stable
        return FileWrapper(regularFileWithContents: try encoder.encode(talk))
    }
}

extension TalkDocument {
    /// Un `.md` ouvert devient un talk sans titre avant toute modification : l'enregistrement crée un `.talk` (§ 5).
    /// `DocumentGroup` repose sur `NSDocument`, qui porte le lien au fichier ; on le coupe là.
    @MainActor static func detachMarkdownFiles() {
        for document in NSDocumentController.shared.documents
        where document.fileURL != nil && UTType(document.fileType ?? "")?.conforms(to: .markdownText) == true {
            document.fileURL = nil
            document.fileType = UTType.talk.identifier
            document.updateChangeCount(.changeDone)  // « Modifié » : fermer propose d'enregistrer en `.talk`
        }
    }
}

/// Le modèle ne porte aucune chaîne (§ 8) : l'app formule les refus, et `DocumentGroup` les affiche.
extension TalkError: @retroactive LocalizedError {
    nonisolated public var errorDescription: String? { message }
    nonisolated public var failureReason: String? { message }  // texte secondaire de l'alerte de `NSDocument`

    nonisolated var message: String {
        switch self {
        case .noBlocks:
            String(localized: "The talk has no blocks.")
        case .badTotal(let total):
            String(localized: "The total length (\(total) min) must be between 1 and \(Talk.maxMinutes) min.")
        case .badMinutes(let title):
            String(localized: "The block “\(title)” must last between 1 and \(Talk.maxMinutes) min.")
        case .overTotal(let sum, let total):
            String(localized: "The blocks add up to \(sum) min, for a total of \(total) min.")
        case .missingDuration(let title):
            String(localized: "The block “\(title)” has no length: end its title with (N min).")
        case .atLine(let line, let error):
            String(localized: "Line \(line): \(error.message)")
        }
    }
}
