import Foundation

struct ScheduleEntry: Identifiable, Decodable, Sendable, Hashable {
    let guideId: Guide
    let day: Int
    let start: String
    let duration: TimeInterval
    let name: String
    let broadcasters: String?
    let slug: String?
    let profileImage: URL?
    let profileImageSmall: URL?
    let onairnow: Bool?

    var id: String { "\(guideId.rawValue)-\(day)-\(start)" }

    var artworkURL: URL? {
        profileImage ?? profileImageSmall
    }

    var displayBroadcasters: String? {
        guard let broadcasters, !broadcasters.isEmpty else { return nil }
        return broadcasters.htmlStripped
    }

    /// "HH:MM:SS" -> minutes since midnight.
    var startMinutes: Int {
        let parts = start.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }

    var startDateComponents: DateComponents {
        DateComponents(hour: startMinutes / 60, minute: startMinutes % 60)
    }
}

enum ScheduleResolver {
    private static var brisbaneCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = BroadcastURL.stationTimeZone
        return calendar
    }

    /// ISO weekday in Brisbane: Monday = 1 ... Sunday = 7.
    private static func isoWeekday(_ date: Date) -> Int {
        let weekday = brisbaneCalendar.component(.weekday, from: date) // 1 = Sunday
        return (weekday + 5) % 7 + 1
    }

    private static func minutesSinceMidnight(_ date: Date) -> Int {
        let components = brisbaneCalendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private static func weekMinutes(day: Int, startMinutes: Int) -> Int {
        (day - 1) * 1440 + startMinutes
    }

    private static func weekMinutes(_ entry: ScheduleEntry) -> Int {
        weekMinutes(day: entry.day, startMinutes: entry.startMinutes)
    }

    static func position(
        in entries: [ScheduleEntry],
        at date: Date = Date()
    ) -> (current: ScheduleEntry?, next: ScheduleEntry?) {
        guard !entries.isEmpty else { return (nil, nil) }

        let sorted = entries.sorted { weekMinutes($0) < weekMinutes($1) }
        let nowWeek = weekMinutes(day: isoWeekday(date), startMinutes: minutesSinceMidnight(date))

        let current = sorted.first { entry in
            let start = weekMinutes(entry)
            let length = Int(entry.duration / 60)
            return nowWeek >= start && nowWeek < start + length
        }

        let next = sorted.first { weekMinutes($0) > nowWeek } ?? sorted.first

        return (current, next)
    }
}
