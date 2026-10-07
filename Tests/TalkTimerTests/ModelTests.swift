import Foundation
import Testing
@testable import TalkTimer

let fixture = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "fixtures/borrowed-from-the-lab.json")

let t0 = Date(timeIntervalSinceReferenceDate: 0)

// Les numéros renvoient aux critères d'acceptation de SPECS.md § 10.

@Test func fixtureLoads() throws {  // 1
    let talk = try Talk.load(from: fixture)
    #expect(talk.blocks.count == 8)
    #expect(talk.totalMinutes == 60)
    #expect(talk.margin == 0)
    #expect(talk.blocks[3].cue != nil)
}

@Test func overTotalIsRefused() throws {  // 7
    var talk = try Talk.load(from: fixture)
    talk.totalMinutes = 59
    #expect(throws: TalkError.overTotal(sum: 60, total: 59)) { try talk.validate() }
}

@Test func backRestoresPreviousBlock() throws {  // 10
    var session = Session(talk: try Talk.load(from: fixture), now: t0)
    session.next(at: t0 + 200)
    #expect(session.index == 1)
    session.back()
    #expect(session.index == 0)
    #expect(session.blockStart == t0)
}

@Test func nextStopsOnLastBlock() throws {
    var session = Session(talk: try Talk.load(from: fixture), now: t0)
    for _ in 0..<20 { session.next(at: t0) }
    #expect(session.index == 7)
}

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
