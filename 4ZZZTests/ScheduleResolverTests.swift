import Foundation
import Testing
@testable import FourZZZ

@Suite("Schedule resolution")
struct ScheduleResolverTests {
    private func entry(day: Int, start: String, name: String, duration: TimeInterval = 3600) -> ScheduleEntry {
        ScheduleEntry(
            guideId: .fm,
            day: day,
            start: start,
            duration: duration,
            name: name,
            broadcasters: nil,
            slug: name.lowercased(),
            profileImage: nil,
            profileImageSmall: nil,
            onairnow: nil
        )
    }

    private func brisbaneDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = BroadcastURL.stationTimeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test("Finds the show currently on air and the next one")
    func currentAndNext() {
        let entries = [
            entry(day: 6, start: "22:00:00", name: "Local Glow", duration: 7200),
            entry(day: 7, start: "00:00:00", name: "The Soundtrack Show"),
            entry(day: 1, start: "00:00:00", name: "Kaleidoscope", duration: 7200),
        ]
        // Saturday 23:00 Brisbane.
        let position = ScheduleResolver.position(in: entries, at: brisbaneDate(2026, 9, 12, 23))
        #expect(position.current?.name == "Local Glow")
        #expect(position.next?.name == "The Soundtrack Show")
    }

    @Test("Wraps around to the start of the week after the last show")
    func wrapsAround() {
        let entries = [
            entry(day: 6, start: "22:00:00", name: "Local Glow", duration: 7200),
            entry(day: 7, start: "00:00:00", name: "The Soundtrack Show"),
            entry(day: 1, start: "00:00:00", name: "Kaleidoscope", duration: 7200),
        ]
        // Sunday 00:30: Soundtrack Show is on, next wraps to Monday's Kaleidoscope.
        let position = ScheduleResolver.position(in: entries, at: brisbaneDate(2026, 9, 13, 0, 30))
        #expect(position.current?.name == "The Soundtrack Show")
        #expect(position.next?.name == "Kaleidoscope")
    }

    @Test("Empty schedule yields nothing")
    func empty() {
        let position = ScheduleResolver.position(in: [], at: brisbaneDate(2026, 9, 12, 23))
        #expect(position.current == nil)
        #expect(position.next == nil)
    }
}
