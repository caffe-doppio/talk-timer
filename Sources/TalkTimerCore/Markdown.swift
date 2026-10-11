import Foundation
import Markdown

// Import et export Markdown : SPECS.md § 3.1. Format d'échange, pas d'enregistrement.

extension Talk {
    /// `# Titre (60 min, auto)`, puis un `## Bloc (N min)` ou `(N min, break)` par bloc, et une citation pour `cue`.
    /// Tout le reste est une note, ignorée. Rien n'est deviné : un refus porte sa ligne (`TalkError.atLine`).
    public init(markdown: String) throws {
        var title = ""
        var total: Int?
        var auto = false
        var titleLine = 1
        var blocks: [Block] = []
        var seenTitle = false

        for child in Document(parsing: markdown).children {
            let line = child.range?.lowerBound.line ?? 1
            if let heading = child as? Heading, heading.level == 1, !seenTitle {
                seenTitle = true
                titleLine = line
                let (text, duration) = Self.split(heading.plainText, keywords: ["auto"])
                title = text
                total = duration?.minutes
                auto = duration?.keyword != nil
            } else if let heading = child as? Heading, heading.level == 2 {
                let (text, duration) = Self.split(heading.plainText, keywords: ["break", "pause"])
                guard let duration else { throw TalkError.atLine(line, .missingDuration(text)) }
                // Bornes vérifiées bloc par bloc, avant toute somme (§ 3).
                guard duration.minutes >= 1, duration.minutes <= Self.maxMinutes else {
                    throw TalkError.atLine(line, .badMinutes(text))
                }
                blocks.append(Block(title: text, minutes: duration.minutes, isBreak: duration.keyword != nil))
            } else if let quote = child as? BlockQuote, let last = blocks.indices.last, blocks[last].cue == nil {
                let paragraphs = quote.children.compactMap { ($0 as? Paragraph)?.plainText }
                if !paragraphs.isEmpty { blocks[last].cue = paragraphs.joined(separator: " ") }
            }
        }

        self.init(title: title, totalMinutes: total ?? blocks.reduce(0) { $0 + $1.minutes }, blocks: blocks, autoAdvance: auto)
        do { try validate() } catch let error as TalkError { throw TalkError.atLine(titleLine, error) }
    }

    /// Exactement le format de `init(markdown:)` : exporter puis réimporter redonne le même talk.
    public var markdown: String {
        var lines = ["# \(Self.escaped(title)) (\(totalMinutes) min\(autoAdvance ? ", auto" : ""))"]
        for block in blocks {
            lines += ["", "## \(Self.escaped(block.title)) (\(block.minutes) min\(block.isBreak ? ", break" : ""))"]
            if let cue = block.cue { lines += ["", "> \(Self.escaped(cue))"] }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Sépare la **dernière** paire de parenthèses : `Demo (live) (3 min)` donne « Demo (live) » et 3.
    /// Le mot-clé ne compte que s'il fait partie de `keywords`, sans tenir compte de la casse.
    private static func split(_ text: String, keywords: [String]) -> (String, (minutes: Int, keyword: String?)?) {
        let pattern = /^(?<title>.*?)\s*\((?<minutes>\d+)\s*min(?:\s*,\s*(?<keyword>\w+))?\)\s*$/.ignoresCase()
        let plain = (text.trimmingCharacters(in: .whitespaces), nil as (minutes: Int, keyword: String?)?)
        guard let match = text.wholeMatch(of: pattern) else { return plain }
        let keyword = match.keyword.map { $0.lowercased() }
        if let keyword, !keywords.contains(keyword) { return plain }
        // Un nombre trop grand pour un `Int` reste refusé par les bornes, au lieu d'être pris pour une absence de durée.
        return (String(match.title), (Int(match.minutes) ?? Int.max, keyword))
    }

    // ponytail: un retour à la ligne dans un titre ou une transition devient une espace à l'aller-retour ;
    // les échapper aussi si un fichier JSON en contient en vrai.
    /// Échappe ce qui changerait le sens du texte : emphase, lien, HTML, `#` de titre, et une liste en tête de citation.
    private static func escaped(_ text: String) -> String {
        var out = ""
        for (index, character) in text.enumerated() {
            if #"\`*_[]#<>&~"#.contains(character) || (index == 0 && "-+".contains(character)) { out.append("\\") }
            out.append(character)
        }
        if let digits = out.firstMatch(of: /^\d+(?=[.)])/) { out.insert("\\", at: digits.range.upperBound) }
        return out
    }
}
