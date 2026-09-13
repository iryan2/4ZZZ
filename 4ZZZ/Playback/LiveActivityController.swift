@preconcurrency import ActivityKit
import Foundation
import UIKit

@MainActor
final class LiveActivityController {
    private var activity: Activity<PlaybackActivityAttributes>?

    private var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func update(
        source: PlaybackSource?,
        isPlaying: Bool,
        elapsed: TimeInterval,
        duration: TimeInterval?,
        artwork: UIImage?
    ) {
        guard let source, isSupported else { return }

        let thumbnail = artwork?
            .preparingThumbnail(of: CGSize(width: 120, height: 120))?
            .jpegData(compressionQuality: 0.6)

        let state = PlaybackActivityAttributes.ContentState(
            title: Self.title(for: source),
            subtitle: Self.subtitle(for: source),
            isLive: source.isLive,
            isPlaying: isPlaying,
            elapsed: elapsed,
            duration: source.isLive ? nil : duration,
            artworkData: thumbnail
        )
        let content = ActivityContent(state: state, staleDate: nil)

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
