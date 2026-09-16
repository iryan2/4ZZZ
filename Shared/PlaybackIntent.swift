import AppIntents
import Foundation

/// Commands sent from the Live Activity controls back into the app.
///
/// The intent is a `LiveActivityIntent`, so it runs inside the app's process
/// rather than the widget's. That lets a tap reach the single
/// `PlaybackCoordinator` without the widget extension ever touching `AVPlayer`.
/// The widget target compiles this file too, so it must not reference app-only
/// types — it talks through the shared handler instead.
@MainActor
enum PlaybackCommandBus {
    enum Command: Sendable {
        case togglePlayPause
    }

    static var handler: (@MainActor (Command) -> Void)?
}

struct TogglePlaybackIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Play or Pause"
    static let isDiscoverable: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            PlaybackCommandBus.handler?(.togglePlayPause)
        }
        return .result()
    }
}
