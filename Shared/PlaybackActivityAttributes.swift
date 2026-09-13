import ActivityKit
import Foundation

/// Shared between the app and the widget extension.
struct PlaybackActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var isLive: Bool
        var isPlaying: Bool
        var elapsed: Double
        var duration: Double?
        var artworkData: Data?
    }

    var startedAt: Date
}
