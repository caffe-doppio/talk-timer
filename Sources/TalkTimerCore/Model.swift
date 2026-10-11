import Foundation

// Logique pure : SPECS.md § 3, § 4, § 6, § 7.3. Module sans AppKit ni SwiftUI (§ 9), sans chaîne d'interface (§ 8).
// Tout calcul de temps reçoit `now` en paramètre : les tests simulent 19 minutes en une ligne.

public struct Block: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()  // généré au chargement, jamais écrit dans le fichier
    public var title: String
    public var minutes: Int
    public var cue: String?
    public var isBreak = false  // pause prévue (§ 6.3)

    enum CodingKeys: String, CodingKey {
        case title, minutes, cue
        case isBreak = "break"  // `break` est un mot réservé en Swift
    }

    public init(title: String, minutes: Int, cue: String? = nil, isBreak: Bool = false) {
        self.title = title
        self.minutes = minutes
        self.cue = cue
        self.isBreak = isBreak
    }

    // Écrit à la main : le décodage synthétisé exigerait la clé `break` même quand elle est absente.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        minutes = try container.decode(Int.self, forKey: .minutes)
        cue = try container.decodeIfPresent(String.self, forKey: .cue)
        isBreak = try container.decodeIfPresent(Bool.self, forKey: .isBreak) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(minutes, forKey: .minutes)
        try container.encodeIfPresent(cue, forKey: .cue)
        if isBreak { try container.encode(true, forKey: .isBreak) }
    }
}

public struct Talk: Codable, Equatable, Sendable {
    /// Borne de toute durée (§ 3) : 24 h. Vérifiée avant toute somme, pour qu'aucun fichier ne fasse déborder un `Int`.
    public static let maxMinutes = 1440

    public var title: String
    public var totalMinutes: Int
    public var blocks: [Block]
    public var autoAdvance = false  // passage automatique (§ 6.3)

    enum CodingKeys: String, CodingKey { case title, totalMinutes, blocks, autoAdvance }

    public init(title: String, totalMinutes: Int, blocks: [Block], autoAdvance: Bool = false) {
        self.title = title
        self.totalMinutes = totalMinutes
        self.blocks = blocks
        self.autoAdvance = autoAdvance
    }

    // Écrit à la main, comme `Block` : `autoAdvance` est facultatif et n'est écrit que s'il vaut `true` (§ 3).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        totalMinutes = try container.decode(Int.self, forKey: .totalMinutes)
        blocks = try container.decode([Block].self, forKey: .blocks)
        autoAdvance = try container.decodeIfPresent(Bool.self, forKey: .autoAdvance) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(totalMinutes, forKey: .totalMinutes)
        try container.encode(blocks, forKey: .blocks)
        if autoAdvance { try container.encode(true, forKey: .autoAdvance) }
    }

    public var margin: Int { totalMinutes - blocks.reduce(0) { $0 + $1.minutes } }

    /// Début de chaque bloc, en minutes depuis le début du talk.
    public var startMinutes: [Int] {
        var start = 0
        return blocks.map { block in
            defer { start += block.minutes }
            return start
        }
    }

    public static func load(from url: URL) throws -> Talk {
        let talk = try JSONDecoder().decode(Talk.self, from: Data(contentsOf: url))
        try talk.validate()
        return talk
    }

    public func validate() throws {
        let bounds = 1...Self.maxMinutes
        if blocks.isEmpty { throw TalkError.noBlocks }
        if !bounds.contains(totalMinutes) { throw TalkError.badTotal(totalMinutes) }
        if let bad = blocks.first(where: { !bounds.contains($0.minutes) }) { throw TalkError.badMinutes(bad.title) }
        if margin < 0 { throw TalkError.overTotal(sum: totalMinutes - margin, total: totalMinutes) }
    }

    // MARK: Règles du planificateur (§ 4). `false` = refusé, rien n'a changé.
    // Comparaisons plutôt que `a...b` : un intervalle fermé arrête le programme si a > b.

    public mutating func setMinutes(_ minutes: Int, at index: Int) -> Bool {
        guard minutes >= 1, minutes <= blocks[index].minutes + margin else { return false }
        blocks[index].minutes = minutes
        return true
    }

    public mutating func addBlock(title: String) -> Bool {
        guard margin >= 1 else { return false }
        blocks.append(Block(title: title, minutes: min(5, margin)))
        return true
    }

    public mutating func setTotal(_ total: Int) -> Bool {
        guard total >= totalMinutes - margin, total <= Self.maxMinutes else { return false }
        totalMinutes = total
        return true
    }
}

/// Motifs de refus au chargement. Aucune chaîne ici : l'app formule le message (§ 8).
public enum TalkError: Error, Equatable, Sendable {
    case noBlocks
    case badTotal(Int)
    case badMinutes(String)
    case overTotal(sum: Int, total: Int)
}

// MARK: - Session en direct (§ 6)

public struct Session: Sendable {
    public let talk: Talk
    public private(set) var index = 0
    public private(set) var talkStart: Date  // jamais décalé : la fin prévue est fixe
    public private(set) var blockStart: Date
    public private(set) var pausedAt: Date?
    public private(set) var furthestIndex = 0  // un bloc d'indice inférieur a été retrouvé par « Précédent »
    public private(set) var isFinished = false
    private var history: [Date] = []

    public init(talk: Talk, now: Date) {
        self.talk = talk
        talkStart = now
        blockStart = now
    }

    public var block: Block { talk.blocks[index] }
    public var nextBlock: Block? { talk.blocks.indices.contains(index + 1) ? talk.blocks[index + 1] : nil }
    public var duration: TimeInterval { TimeInterval(block.minutes * 60) }

    /// Négatif en dépassement. Figé pendant une suspension : on mesure jusqu'à `pausedAt`.
    public func remaining(at now: Date) -> TimeInterval { duration - (pausedAt ?? now).timeIntervalSince(blockStart) }

    public func projectedEnd(at now: Date) -> Date {
        let rest = talk.blocks[(index + 1)...].reduce(0) { $0 + $1.minutes }
        return now + max(0, remaining(at: now)) + TimeInterval(rest * 60)
    }

    /// Positif : fin en retard. Une suspension le fait monter, car `projectedEnd` avance avec `now`.
    public func endOffset(at now: Date) -> TimeInterval {
        projectedEnd(at: now).timeIntervalSince(talkStart + TimeInterval(talk.totalMinutes * 60))
    }

    public func phase(at now: Date) -> Phase {
        // `TalkTimerCore.` est nécessaire : dans le type, `phase` désignerait cette méthode et masquerait la fonction libre.
        pausedAt == nil ? TalkTimerCore.phase(remaining: remaining(at: now), duration: duration) : .paused
    }

    /// Sans effet sur le dernier bloc : seule `end()` termine (§ 6.3).
    /// Pendant une suspension, le bloc suivant démarre figé à sa durée pleine (`blockStart = pausedAt`).
    public mutating func next(at now: Date) {
        guard nextBlock != nil else { return }
        history.append(blockStart)
        index += 1
        furthestIndex = max(furthestIndex, index)
        blockStart = pausedAt ?? now
    }

    /// Passage automatique (§ 6.3), déduit de l'horloge : un seul appel rattrape plusieurs blocs après une veille.
    /// Le bloc suivant commence à la fin exacte du précédent, pas à `now` : un rafraîchissement en retard ne décale rien.
    public mutating func catchUp(at now: Date) {
        guard talk.autoAdvance, pausedAt == nil else { return }
        while index == furthestIndex, !block.isBreak, nextBlock != nil, remaining(at: now) <= 0 {
            history.append(blockStart)
            blockStart += duration
            index += 1
            furthestIndex = index
        }
    }

    public mutating func end() { isFinished = true }

    // ponytail: une suspension faite après « Suivant » puis annulée par « Précédent » compte comme du temps
    // écoulé dans le bloc précédent ; décaler aussi `history` à la reprise si ce cas gêne en vrai.
    public mutating func back() {
        guard let previous = history.popLast() else { return }
        index -= 1
        blockStart = previous
    }

    /// Suspendre fige le bloc ; reprendre décale seulement `blockStart` (§ 6.3).
    public mutating func togglePause(at now: Date) {
        if let pausedAt {
            blockStart += now.timeIntervalSince(pausedAt)
            self.pausedAt = nil
        } else {
            pausedAt = now
        }
    }
}

// MARK: - Affichage de la barre (§ 7.3)

public enum Phase: Sendable { case normal, alert, overtime, paused }

/// Alerte quand il reste au plus max(20 % de la durée, 60 s) : on retient le seuil le plus précoce.
public func phase(remaining: TimeInterval, duration: TimeInterval) -> Phase {
    if remaining < 0 { return .overtime }
    return remaining <= max(duration * 0.2, 60) ? .alert : .normal
}

/// `1:30` en compte à rebours (arrondi au-dessus : 0:00 seulement à la fin), `+1:01` en dépassement.
public func clock(_ remaining: TimeInterval) -> String {
    let overtime = remaining < 0
    let seconds = Int(overtime ? (-remaining).rounded(.down) : remaining.rounded(.up))
    return (overtime ? "+" : "") + String(format: "%d:%02d", seconds / 60, seconds % 60)
}
