import Foundation
import Testing
@testable import FourZZZ

@Suite("Program keywords")
struct ProgramKeywordTests {
    @Test("Merges repeated slots and de-duplicates tags")
    func mergesKeywords() throws {
        let json = #"""
        {"programs":[
          {"program":{"slug":"goo","keywords":[{"tag":"Alternative"},{"tag":"Punk"}]}},
          {"program":{"slug":"goo","keywords":[{"tag":"Punk"},{"tag":"Rock"}]}},
          {"program":{"slug":"other","keywords":[{"tag":"Jazz"}]}},
          {"program":{"slug":"","keywords":[{"tag":"Ignored"}]}},
          {"program":{"slug":null,"keywords":[{"tag":"Ignored"}]}}
        ]}
        """#

        let map = try ProgramKeywordCatalog.keywordsBySlug(
            from: Data(json.utf8),
            decoder: AirNetClient.decoder
        )

        #expect(map["goo"] == ["Alternative", "Punk", "Rock"])
        #expect(map["other"] == ["Jazz"])
        #expect(map[""] == nil)
        #expect(map.count == 2)
    }

    @Test("Grid keywords take precedence over local overrides")
    func overridePrecedence() {
        let grid = ["goo": ["Punk"], "a-new-jazz-soul": ["GridTag"]]
        #expect(ProgramTagOverrides.tags(for: "goo", grid: grid) == ["Punk"])
        #expect(ProgramTagOverrides.tags(for: "a-new-jazz-soul", grid: grid) == ["GridTag"])
        #expect(ProgramTagOverrides.tags(for: "talker-space", grid: grid) == ["Local", "Brisbane", "Youth", "Music"])
        #expect(ProgramTagOverrides.tags(for: "not-a-program", grid: grid).isEmpty)
    }

    @Test("Overrides still apply when the grid feed is unavailable")
    func overrideFallback() {
        #expect(ProgramTagOverrides.tags(for: "shoegrazzze", grid: [:]) == ["Shoegaze", "Indie", "Ambient", "Dream Pop"])
    }
}
