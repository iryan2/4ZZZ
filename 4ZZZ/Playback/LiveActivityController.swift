@preconcurrency import ActivityKit
import Foundation
import UIKit

@MainActor
final class LiveActivityController {
    private var activity: Activity<PlaybackActivityAttributes>?

    /// Content the last successful push described. Used to skip redundant
    /// updates (the coordinator polls every 500 ms) and to decide whether a
    /// new activity is needed.
    private var signature: Signature?

    private struct Signature: Equatable {
        var title: String
        var subtitle: String
        var isLive: Bool
        var isPlaying: Bool
        var artwork: ObjectIdentifier?
    }

    private var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    init() {
        endStrayActivities()
    }

    /// Live Activities outlive the app process. If the app was terminated while
    /// one was still on screen, starting a fresh one at launch would leave two
    /// identical cards, so clear anything left over first.
    private func endStrayActivities() {
        for existing in Activity<PlaybackActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func update(
        source: PlaybackSource?,
        isPlaying: Bool,
        elapsed: TimeInterval,
        duration: TimeInterval?,
        artwork: UIImage?
    ) {
        guard let source, isSupported else { return }

        let title = Self.title(for: source)
        let subtitle = Self.subtitle(for: source)
        let next = Signature(
            title: title,
            subtitle: subtitle,
            isLive: source.isLive,
            isPlaying: isPlaying,
            artwork: artwork.map { ObjectIdentifier($0) }
        )
        guard activity == nil || next != signature else { return }

        let thumbnail = artwork?
            .preparingThumbnail(of: CGSize(width: 120, height: 120))?
            .jpegData(compressionQuality: 0.6)

        let state = PlaybackActivityAttributes.ContentState(
            title: title,
            subtitle: subtitle,
            isLive: source.isLive,
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: source.isLive ? nil : duration,
            artworkData: thumbnail
        )
        let content = ActivityContent(
            state: state,
            staleDate: Date().addingTimeInterval(8 * 60 * 60)
        )

        signature = next

        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(
                attributes: PlaybackActivityAttributes(startedAt: Date()),
                content: content,
                pushType: nil
            )
        }
    }

    func end() async {
        signature = nil
        guard let activity else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        self.activity = nil
    }

    private static func title(for source: PlaybackSource) -> String {
        switch source {
        case .live(let guide): return "Live — \(guide.displayName)"
        case .episode(_, let showName, _, let episodeTitle, _, _, _): return episodeTitle ?? showName
        }
    }

    private static func subtitle(for source: PlaybackSource) -> String {
        switch source {
        case .live: return "4ZZZ Community Radio"
        case .episode(_, let showName, _, _, _, _, _): return showName
        }
    }
}
