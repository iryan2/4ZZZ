import Foundation
import Testing
@testable import FourZZZ

@Suite("Broadcast URLs")
struct BroadcastURLTests {
    @Test("FM on-demand URL uses the 4zzz feed and date-hour pattern")
    func fmOnDemandURL() throws {
        let start = try #require(BroadcastURL.parseStationDate("2026-09-09 15:00:00"))
        let url = BroadcastURL.onDemandURL(guide: .fm, start: start)
        #expect(url.absoluteString == "https://undead.4zzz.fm/4zzz/2026-09-09-15-00.mp3")
    }

    @Test("Digital on-demand URL uses the zed-digital feed and ZD prefix")
    func digitalOnDemandURL() throws {
        let start = try #require(BroadcastURL.parseStationDate("2026-09-09 15:00:00"))
        let url = BroadcastURL.onDemandURL(guide: .digital, start: start)
        #expect(url.absoluteString == "https://undead.4zzz.fm/zed-digital/ZD-2026-09-09-15-00.mp3")
    }

    @Test("Station dates are parsed in Brisbane time (UTC+10)")
    func parsesBrisbaneDates() throws {
        let parsed = try #require(BroadcastURL.parseStationDate("2026-09-09 15:00:00"))

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let expected = try #require(
            utc.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 5, minute: 0, second: 0))
        )

        #expect(abs(parsed.timeIntervalSince(expected)) < 1)
    }

    @Test("Malformed station dates return nil")
    func rejectsMalformedDates() {
        #expect(BroadcastURL.parseStationDate("not a date") == nil)
        #expect(BroadcastURL.parseStationDate("2026-09-09") == nil)
    }

    @Test("Live URLs are HTTPS")
    func liveURLs() {
        #expect(Guide.fm.liveURL.absoluteString == "https://iheart.4zzz.org.au/4zzz")
        #expect(Guide.digital.liveURL.absoluteString == "https://iheart.4zzz.org.au/zed-digital")
    }
}
