import Foundation
import Testing
@testable import FourZZZ

@Suite("Formatting")
struct StationFormatTests {
    @Test("Clock formats hours and minutes")
    func clock() {
        #expect(StationFormat.clock(0) == "0:00")
        #expect(StationFormat.clock(67) == "1:07")
        #expect(StationFormat.clock(3661) == "1:01:01")
        #expect(StationFormat.clock(.nan) == "0:00")
    }

    @Test("Human duration")
    func duration() {
        #expect(StationFormat.duration(10800) == "3 hr 0 min")
        #expect(StationFormat.duration(90) == "1 min")
        #expect(StationFormat.duration(0) == "—")
    }

    @Test("Weekly schedule times use ISO weekdays in station time")
    func scheduleTime() {
        let entry = ScheduleEntry(
            guideId: .fm,
            day: 6,
            start: "22:00:00",
            duration: 7200,
            name: "Local Glow",
            broadcasters: nil,
            slug: "local-glow",
            profileImage: nil,
            profileImageSmall: nil,
            onairnow: nil
        )
        #expect(StationFormat.time(from: entry) == "Sat 22:00")
    }
}

@Suite("Library model")
struct ListeningProgressTests {
    private func progress(position: TimeInterval, duration: TimeInterval) -> ListeningProgress {
        ListeningProgress(
            episodeID: "ep-1",
            showSlug: "goo",
            showName: "Goo",
            title: "Goo — 9 Sep 2026",
            start: Date(),
            guide: .fm,
            artworkURL: nil,
            duration: duration,
            position: position,
            updatedAt: Date(),
            completed: false
        )
    }

    @Test("Progress fraction is clamped")
    func fraction() {
        #expect(progress(position: 50, duration: 100).fraction == 0.5)
        #expect(progress(position: 200, duration: 100).fraction == 1)
        #expect(progress(position: -10, duration: 100).fraction == 0)
        #expect(progress(position: 10, duration: 0).fraction == 0)
    }

    @Test("Progress converts back into a playable source")
    func playbackSource() {
        let source = progress(position: 50, duration: 100).playbackSource
        #expect(source.episodeID == "ep-1")
        #expect(source.showSlug == "goo")
        #expect(source.isLive == false)
    }

    @Test("Playback sources survive a JSON round trip")
    func sourceCoding() throws {
        let episode = PlaybackSource.episode(
            showSlug: "goo",
            showName: "Goo",
            episodeID: "ep-1",
            title: "Goo — 9 Sep 2026",
            start: Date(timeIntervalSince1970: 1_700_000_000),
            guide: .digital,
            artworkURL: URL(string: "https://example.com/art.jpg")
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode([episode, PlaybackSource.live(.fm)])
        let decoded = try decoder.decode([PlaybackSource].self, from: data)

        #expect(decoded == [episode, .live(.fm)])
    }
}
