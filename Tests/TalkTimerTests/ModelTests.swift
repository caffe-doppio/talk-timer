import Foundation
import Testing
@testable import TalkTimer

let fixture = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "fixtures/borrowed-from-the-lab.json")

// Critère d'acceptation 1 (SPECS.md § 10).
@Test func fixtureLoads() throws {
    let talk = try JSONDecoder().decode(Talk.self, from: Data(contentsOf: fixture))
    #expect(talk.blocks.count == 8)
    #expect(talk.totalMinutes == 60)
    #expect(talk.margin == 0)
    #expect(talk.blocks[3].cue != nil)
}
