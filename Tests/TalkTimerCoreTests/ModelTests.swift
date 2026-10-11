import Foundation
import Testing
@testable import TalkTimerCore

let fixture = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "fixtures/borrowed-from-the-lab.json")

let t0 = Date(timeIntervalSinceReferenceDate: 0)

func minutes(_ value: Double) -> TimeInterval { value * 60 }

/// Applique une règle du § 4 hors de `#expect` : la macro capture ses opérandes en lecture seule
/// (pour afficher leurs valeurs en cas d'échec), donc une méthode `mutating` n'y est pas appelable.
func apply(_ talk: inout Talk, _ rule: (inout Talk) -> Bool) -> Bool { rule(&talk) }

func decode(_ json: String) throws -> Talk {
    let talk = try JSONDecoder().decode(Talk.self, from: Data(json.utf8))
    try talk.validate()
    return talk
}

// Les numéros renvoient aux critères d'acceptation de SPECS.md § 10.

// MARK: - Fichier et règles du planificateur (§ 3, § 4)

@Test func fixtureLoads() throws {  // 1
    let talk = try Talk.load(from: fixture)
    #expect(talk.blocks.count == 8)
    #expect(talk.totalMinutes == 60)
    #expect(talk.margin == 0)
    #expect(talk.blocks[3].cue != nil)
}

@Test func extendingWithoutMarginIsRefused() throws {  // 2
    var talk = try Talk.load(from: fixture)
    #expect(apply(&talk) { $0.setMinutes(16, at: 4) } == false)
    #expect(talk.blocks[4].minutes == 15)
}

@Test func shorteningFreesMargin() throws {  // 3
    var talk = try Talk.load(from: fixture)
    #expect(apply(&talk) { $0.setMinutes(6, at: 7) } == true)
    #expect(talk.margin == 1)
    #expect(apply(&talk) { $0.setMinutes(16, at: 4) } == true)
    #expect(talk.margin == 0)
}

@Test func removingReturnsMinutesToMargin() throws {  // 4
    var talk = try Talk.load(from: fixture)
    talk.blocks.remove(at: 5)
    #expect(talk.margin == 8)
}

@Test func addingWithoutMarginIsRefused() throws {  // 5
    var talk = try Talk.load(from: fixture)
    #expect(apply(&talk) { $0.addBlock(title: "Q&A") } == false)
    #expect(talk.blocks.count == 8)
    #expect(apply(&talk) { $0.setTotal(63) } == true)
    #expect(apply(&talk) { $0.addBlock(title: "Q&A") } == true)
    #expect(talk.blocks.last?.minutes == 3)  // min(5, marge)
}

@Test func totalBelowSumIsRefused() throws {  // 6
    var talk = try Talk.load(from: fixture)
    #expect(apply(&talk) { $0.setTotal(59) } == false)
    #expect(talk.totalMinutes == 60)
    #expect(apply(&talk) { $0.setTotal(Talk.maxMinutes + 1) } == false)
}

@Test func overTotalIsRefused() throws {  // 7
    var talk = try Talk.load(from: fixture)
    talk.totalMinutes = 59
    #expect(throws: TalkError.overTotal(sum: 60, total: 59)) { try talk.validate() }
}

@Test func boundsAreCheckedBeforeSumming() throws {  // 11
    let block = #"{ "title": "Long", "minutes": 1441 }"#
    #expect(throws: TalkError.badMinutes("Long")) { try decode(#"{ "title": "", "totalMinutes": 1440, "blocks": [\#(block)] }"#) }
    let short = #"{ "title": "Short", "minutes": 5 }"#
    #expect(throws: TalkError.badTotal(1441)) { try decode(#"{ "title": "", "totalMinutes": 1441, "blocks": [\#(short)] }"#) }

    // Sans les bornes, la somme de deux Int.max arrêterait le programme.
    let huge = #"{ "title": "Huge", "minutes": \#(Int.max) }"#
    #expect(throws: TalkError.badMinutes("Huge")) {
        try decode(#"{ "title": "", "totalMinutes": 60, "blocks": [\#(huge), \#(huge)] }"#)
    }
}

@Test func plannedBreakIsOptionalInFile() throws {  // 13
    let talk = try decode(#"""
        { "title": "", "totalMinutes": 20, "blocks": [
            { "title": "Talk", "minutes": 10 },
            { "title": "Coffee", "minutes": 10, "break": true }
        ] }
        """#)
    #expect(talk.blocks.map(\.isBreak) == [false, true])

    let written = String(decoding: try JSONEncoder().encode(talk), as: UTF8.self)
    #expect(written.components(separatedBy: "\"break\"").count == 2)  // écrit une seule fois, pour Coffee
}

@Test func startMinutesAreCumulative() throws {
    #expect(try Talk.load(from: fixture).startMinutes == [0, 3, 8, 15, 18, 33, 41, 53])
}

// MARK: - Session en direct (§ 6)

@Test func endOffsetCountsOvertime() throws {  // 8
    var talk = try Talk.load(from: fixture)
    var session = Session(talk: talk, now: t0)
    for start in [3.0, 8, 15, 18] { session.next(at: t0 + minutes(start)) }  // blocs 1 à 4 tenus
    let now = t0 + minutes(37)  // bloc 5 (15 min) commencé depuis 19 min
    #expect(session.endOffset(at: now) == minutes(4))

    talk.totalMinutes = 65
    session = Session(talk: talk, now: t0)
    for start in [3.0, 8, 15, 18] { session.next(at: t0 + minutes(start)) }
    #expect(session.endOffset(at: now) == minutes(-1))
}

@Test func suspensionFreezesBlockButNotEnd() throws {  // 9
    var session = Session(talk: try Talk.load(from: fixture), now: t0)
    session.next(at: t0 + minutes(3))  // bloc 2 : 5 min
    let before = t0 + minutes(4)
    #expect(session.remaining(at: before) == minutes(4))
    #expect(session.endOffset(at: before) == 0)

    session.togglePause(at: before)
    let during = t0 + minutes(6)
    #expect(session.phase(at: during) == .paused)
    #expect(session.remaining(at: during) == minutes(4))
    #expect(session.endOffset(at: during) == minutes(2))  // la fin est fixe : la suspension se paie

    session.togglePause(at: during)
    #expect(session.phase(at: during) == .normal)
    #expect(session.remaining(at: during) == minutes(4))
    #expect(session.endOffset(at: during) == minutes(2))
}

@Test func nextDuringSuspensionStartsFrozen() throws {
    var session = Session(talk: try Talk.load(from: fixture), now: t0)
    session.togglePause(at: t0 + minutes(1))
    session.next(at: t0 + minutes(2))
    #expect(session.remaining(at: t0 + minutes(9)) == minutes(5))  // bloc 2 figé à sa durée pleine
}

@Test func backRestoresPreviousBlock() throws {  // 10
    var session = Session(talk: try Talk.load(from: fixture), now: t0)
    session.next(at: t0 + 200)
    #expect(session.index == 1)
    session.back()
    #expect(session.index == 0)
    #expect(session.blockStart == t0)
}

@Test func nextOnLastBlockFinishes() throws {  // 12
    var session = Session(talk: try Talk.load(from: fixture), now: t0)
    for _ in 0..<7 { session.next(at: t0) }
    #expect(session.index == 7)
    #expect(!session.isFinished)
    session.next(at: t0)
    #expect(session.index == 7)
    #expect(session.isFinished)
}

// MARK: - Affichage de la barre (§ 7.3)

@Test func phaseThresholds() {
    #expect(phase(remaining: 181, duration: 900) == .normal)  // 15 min : alerte à 3:00
    #expect(phase(remaining: 180, duration: 900) == .alert)
    #expect(phase(remaining: 61, duration: 180) == .normal)  // 3 min : alerte à 1:00
    #expect(phase(remaining: 60, duration: 180) == .alert)
    #expect(phase(remaining: 0, duration: 180) == .alert)
    #expect(phase(remaining: -1, duration: 180) == .overtime)
}

@Test func clockFormat() {
    #expect(clock(90) == "1:30")
    #expect(clock(0.4) == "0:01")
    #expect(clock(0) == "0:00")
    #expect(clock(-61.7) == "+1:01")
}
