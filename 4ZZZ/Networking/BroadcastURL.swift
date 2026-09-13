import Foundation

/// All broadcast times are in 4ZZZ's home timezone (Brisbane, AEST, no daylight
/// saving), regardless of where the listener is. `DateFormatter` is avoided so
/// this stays concurrency-safe.
enum BroadcastURL {
    static let stationTimeZone = TimeZone(identifier: "Australia/Brisbane")!

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = stationTimeZone
        return calendar
    }

    /// Builds the on-demand recording URL for a broadcast.
    ///
    /// FM:      https://undead.4zzz.fm/4zzz/2026-09-09-15-00.mp3
    /// Digital: https://undead.4zzz.fm/zed-digital/ZD-2026-09-09-15-00.mp3
    static func onDemandURL(guide: Guide, start: Date) -> URL {
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: start)
        let day = String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1
        )
        let hour = String(format: "%02d", components.hour ?? 0)

        switch guide {
        case .fm:
            return URL(string: "https://undead.4zzz.fm/4zzz/\(day)-\(hour)-00.mp3")!
        case .digital:
            return URL(string: "https://undead.4zzz.fm/zed-digital/ZD-\(day)-\(hour)-00.mp3")!
        }
    }

    /// Parses an AirNet timestamp such as "2026-09-09 15:00:00" as Brisbane time.
    static func parseStationDate(_ string: String) -> Date? {
        let halves = string.split(separator: " ")
        guard halves.count == 2 else { return nil }

        let dateParts = halves[0].split(separator: "-").compactMap { Int($0) }
        let timeParts = halves[1].split(separator: ":").compactMap { Int($0) }
        guard dateParts.count == 3, timeParts.count >= 2 else { return nil }

        var components = DateComponents()
        components.year = dateParts[0]
        components.month = dateParts[1]
        components.day = dateParts[2]
        components.hour = timeParts[0]
        components.minute = timeParts[1]
        components.second = timeParts.count > 2 ? timeParts[2] : 0

        return calendar.date(from: components)
    }
}
