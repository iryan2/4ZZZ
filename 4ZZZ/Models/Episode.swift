import Foundation

struct Episode: Identifiable, Decodable, Sendable, Hashable {
    let start: Date
    let end: Date?
    let duration: TimeInterval
    let title: String?
    let description: String?
    let imageUrl: URL?
    let smallImageUrl: URL?
    let episodeRestUrl: URL?

    var id: String {
        episodeRestUrl?.absoluteString ?? "\(start.timeIntervalSince1970)"
    }

    var displayTitle: String? {
        guard let title, !title.isEmpty else { return nil }
        return title.htmlStripped
    }

    var displayDescription: String? {
        guard let description, !description.isEmpty else { return nil }
        return description.htmlStripped
    }

    var artworkURL: URL? {
        imageUrl ?? smallImageUrl
    }
}
