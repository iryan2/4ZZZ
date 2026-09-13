import Foundation

enum StationFormat {
    static func dateTime(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .shortened,
                timeZone: BroadcastURL.stationTimeZone
            )
        )
    }

    static func day(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .omitted,
                timeZone: BroadcastURL.stationTimeZone
            )
        )
    }

    static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours) hr \(minutes) min" : "\(minutes) min"
    }

    /// Clock-style duration: "1:23:45" or "4:07".
    static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
        }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static let weekdayNames = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// "Sat 22:00" for a weekly schedule entry (ISO weekday, station time).
    static func time(from entry: ScheduleEntry) -> String {
        let name = weekdayNames[min(max(entry.day, 0), 7)]
        let hour = entry.startMinutes / 60
        let minute = entry.startMinutes % 60
        return String(format: "%@ %02d:%02d", name, hour, minute)
    }
}
