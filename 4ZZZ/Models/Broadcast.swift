import Foundation

enum Guide: String, Codable, Sendable, CaseIterable, Identifiable {
    case fm
    case digital

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fm: return "102.1FM"
        case .digital: return "Zed Digital"
        }
    }

    var liveURL: URL {
        switch self {
        case .fm: return URL(string: "https://iheart.4zzz.org.au/4zzz")!
        case .digital: return URL(string: "https://iheart.4zzz.org.au/zed-digital")!
        }
    }
}

enum PlaybackSource: Equatable, Sendable {
    case live(Guide)
    case episode(
        showSlug: String,
        showName: String,
        episodeID: String,
        title: String?,
        start: Date,
        guide: Guide,
        artworkURL: URL?
    )

    var isLive: Bool {
        if case .live = self { return true }
        return false
    }

    var artworkURL: URL? {
        switch self {
        case .live: return nil
        case .episode(_, _, _, _, _, _, let artworkURL): return artworkURL
        }
    }

    var episodeID: String? {
        switch self {
        case .live: return nil
        case .episode(_, _, let episodeID, _, _, _, _): return episodeID
        }
    }

    var showSlug: String? {
        switch self {
        case .live: return nil
        case .episode(let showSlug, _, _, _, _, _, _): return showSlug
        }
    }

    var episodeStart: Date? {
        switch self {
        case .live: return nil
        case .episode(_, _, _, _, let start, _, _): return start
        }
    }

    var guide: Guide {
        switch self {
        case .live(let guide): return guide
        case .episode(_, _, _, _, _, let guide, _): return guide
        }
    }

    var audioURL: URL {
        switch self {
        case .live(let guide):
            return guide.liveURL
        case .episode(_, _, _, _, let start, let guide, _):
            return BroadcastURL.onDemandURL(guide: guide, start: start)
        }
    }
}
