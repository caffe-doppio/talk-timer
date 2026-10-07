import Foundation

// Contrat de fichier : SPECS.md § 3. Aucun import AppKit/SwiftUI ici.

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
}
