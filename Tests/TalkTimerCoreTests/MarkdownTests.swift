import Foundation
import Testing
@testable import TalkTimerCore

// Critères 14 à 18 et 23 de SPECS.md § 10 : import et export Markdown (§ 3.1).

let markdownFixture = fixture.deletingPathExtension().appendingPathExtension("md")

/// Égalité aux identifiants de bloc près : l'encodage JSON ne les écrit pas.
func sameTalk(_ lhs: Talk, _ rhs: Talk) throws -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    return try encoder.encode(lhs) == encoder.encode(rhs)
}

@Test func markdownFixtureMatchesJSON() throws {  // 14
    let imported = try Talk(markdown: String(contentsOf: markdownFixture, encoding: .utf8))
    #expect(try sameTalk(imported, Talk.load(from: fixture)))
}

@Test func roundTripKeepsEverything() throws {  // 15
    let talk = Talk(title: "C# & *stars* <b>", totalMinutes: 45, blocks: [
        Block(title: "Demo (live)", minutes: 3, cue: "> not a quote, # not a title"),
        Block(title: "Talk (5 min)", minutes: 7, cue: "1. not a list"),
        Block(title: "Coffee", minutes: 10, isBreak: true),
        Block(title: "_under_ `code` [link](x) ~strike~ \\ end", minutes: 5, cue: "- not a list either"),
    ], autoAdvance: true)
    #expect(try sameTalk(Talk(markdown: talk.markdown), talk))

    let fixtureTalk = try Talk.load(from: fixture)
    #expect(try sameTalk(Talk(markdown: fixtureTalk.markdown), fixtureTalk))
}

@Test func markdownRefusalsCarryTheLine() {  // 16
    #expect(throws: TalkError.atLine(5, .missingDuration("No length"))) {
        try Talk(markdown: "# Talk (10 min)\n\n## Intro (5 min)\n\n## No length\n")
    }
    #expect(throws: TalkError.atLine(1, .noBlocks)) { try Talk(markdown: "# Talk (10 min)\n\nOnly notes.\n") }
    #expect(throws: TalkError.atLine(3, .overTotal(sum: 12, total: 10))) {
        try Talk(markdown: "Notes first.\n\n# Talk (10 min)\n\n## A (6 min)\n\n## B (6 min)\n")
    }
    #expect(throws: TalkError.atLine(3, .badMinutes("Huge"))) {
        try Talk(markdown: "# Talk\n\n## Huge (99999999999999999999 min)\n")
    }
}

@Test func markdownDefaults() throws {  // 17
    let talk = try Talk(markdown: "# Workshop\n\n## Talk (20 min)\n\n## Coffee (10 min, Pause)\n")
    #expect(talk.title == "Workshop")
    #expect(talk.totalMinutes == 30)
    #expect(talk.margin == 0)
    #expect(talk.blocks.map(\.isBreak) == [false, true])
    #expect(try Talk(markdown: "## Solo (5 min)\n").title == "")
}

@Test func markdownAutoAdvance() throws {  // 23
    let talk = try Talk(markdown: "# Title (60 min, auto)\n\n## Block (60 min)\n")
    #expect(talk.autoAdvance)
    #expect(talk.markdown.hasPrefix("# Title (60 min, auto)\n"))
    let plain = try Talk(markdown: "# Title (auto)\n\n## Block (5 min)\n")
    #expect(plain.title == "Title (auto)")
    #expect(!plain.autoAdvance)
}
