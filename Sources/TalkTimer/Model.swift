import Foundation

// Logique pure : SPECS.md § 3, § 6, § 7.3. Aucun import AppKit/SwiftUI ici.
// Tout calcul de temps reçoit `now` en paramètre : les tests simulent 19 minutes en une ligne.

struct Block: Codable, Identifiable, Equatable {
    var id = UUID()  // généré au chargement, jamais écrit dans le fichier
    var title: String
    var minutes: Int
    var cue: String?

    enum CodingKeys: String, CodingKey { case title, minutes, cue }
}

struct Talk: Codable, Equatable {
    var title: String
    var totalMinutes: Int
    var blocks: [Block]

    var margin: Int { totalMinutes - blocks.reduce(0) { $0 + $1.minutes } }

    static func load(from url: URL) throws -> Talk {
        let talk = try JSONDecoder().decode(Talk.self, from: Data(contentsOf: url))
        try talk.validate()
        return talk
    }

    func validate() throws {
        if blocks.isEmpty { throw TalkError.noBlocks }
        if let bad = blocks.first(where: { $0.minutes < 1 }) { throw TalkError.badMinutes(bad.title) }
        if margin < 0 { throw TalkError.overTotal(sum: totalMinutes - margin, total: totalMinutes) }
    }
}

enum TalkError: LocalizedError, Equatable {
    case noBlocks
    case badMinutes(String)
    case overTotal(sum: Int, total: Int)

    var errorDescription: String? {
        switch self {
        case .noBlocks: "Le talk ne contient aucun bloc."
        case .badMinutes(let title): "Le bloc « \(title) » doit durer au moins 1 minute."
        case .overTotal(let sum, let total): "Les blocs totalisent \(sum) min pour un total de \(total) min."
        }
    }
}

// MARK: - Session en direct (§ 6)

struct Session {
    let talk: Talk
    private(set) var index = 0
    private(set) var blockStart: Date
    private var history: [Date] = []

    init(talk: Talk, now: Date) {
        self.talk = talk
        blockStart = now
    }

    var block: Block { talk.blocks[index] }
    var nextBlock: Block? { talk.blocks.indices.contains(index + 1) ? talk.blocks[index + 1] : nil }
    var duration: TimeInterval { TimeInterval(block.minutes * 60) }

    /// Négatif en dépassement.
    func remaining(at now: Date) -> TimeInterval { duration - now.timeIntervalSince(blockStart) }

    // ponytail: sur le dernier bloc, Suivant ne fait rien ; la fin de session vient avec le planificateur.
    mutating func next(at now: Date) {
        guard nextBlock != nil else { return }
        history.append(blockStart)
        index += 1
        blockStart = now
    }

    mutating func back() {
        guard let previous = history.popLast() else { return }
        index -= 1
        blockStart = previous
    }
}

// MARK: - Affichage de la barre (§ 7.3)

enum Phase { case normal, alert, overtime }

/// Alerte quand il reste au plus max(20 % de la durée, 60 s) : on retient le seuil le plus précoce.
func phase(remaining: TimeInterval, duration: TimeInterval) -> Phase {
    if remaining < 0 { return .overtime }
    return remaining <= max(duration * 0.2, 60) ? .alert : .normal
}

/// `1:30` en compte à rebours (arrondi au-dessus : 0:00 seulement à la fin), `+1:01` en dépassement.
func clock(_ remaining: TimeInterval) -> String {
    let overtime = remaining < 0
    let seconds = Int(overtime ? (-remaining).rounded(.down) : remaining.rounded(.up))
    return (overtime ? "+" : "") + String(format: "%d:%02d", seconds / 60, seconds % 60)
}
