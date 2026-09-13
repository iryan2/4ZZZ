import Foundation
import Testing
@testable import FourZZZ

@Suite("AirNet decoding")
struct AirNetDecodingTests {
    @Test("Programs tolerate null slugs")
    func programWithNullSlug() throws {
        let json = #"{"slug":null,"name":"ZedTrain","broadcasters":"Bronwen","archived":false}"#
        let program = try AirNetClient.decoder.decode(Program.self, from: Data(json.utf8))
        #expect(program.slug == nil)
        #expect(!program.hasUsableSlug)
        #expect(program.name == "ZedTrain")
    }

    @Test("Episodes decode station dates in Brisbane time")
    func episodeDate() throws {
        let json = #"""
        {
          "url": null,
          "start": "2026-09-09 15:00:00",
          "end": "2026-09-09 18:00:00",
          "duration": 10800,
          "title": null,
          "description": null,
          "imageUrl": null,
          "smallImageUrl": null,
          "episodeRestUrl": "https://airnet.org.au/rest/stations/4ZZZ/programs/goo/episodes/2026-09-09+15%3A00%3A00"
        }
        """#
        let episode = try AirNetClient.decoder.decode(Episode.self, from: Data(json.utf8))
        #expect(episode.duration == 10800)
        #expect(episode.title == nil)

        let expected = try #require(BroadcastURL.parseStationDate("2026-09-09 15:00:00"))
        #expect(episode.start == expected)
    }

    @Test("HTML fragments are stripped and entities decoded")
    func htmlStripping() {
        #expect("<p>Hello &amp; welcome</p>".htmlStripped == "Hello & welcome")
        #expect("Kate &amp; Josh".htmlStripped == "Kate & Josh")
    }
}
