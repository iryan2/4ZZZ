import Foundation
import ShazamKit

/// An identified song, distilled from a ShazamKit media item into the handful of
/// fields the UI shows. Keeping it a plain value type makes the mapping testable
/// without a real match.
struct TrackMatch: Equatable, Sendable {
    var title: String?
    var artist: String?
    var artworkURL: URL?
    var appleMusicURL: URL?
    var webURL: URL?
    var genres: [String] = []

    init(
        title: String? = nil,
        artist: String? = nil,
        artworkURL: URL? = nil,
        appleMusicURL: URL? = nil,
        webURL: URL? = nil,
        genres: [String] = []
    ) {
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.appleMusicURL = appleMusicURL
        self.webURL = webURL
        self.genres = genres
    }

    init(mediaItem: SHMediaItem) {
        title = mediaItem.title
        artist = mediaItem.artist
        artworkURL = mediaItem.artworkURL
        appleMusicURL = mediaItem.appleMusicURL
        webURL = mediaItem.webURL
        genres = mediaItem.genres
    }

    var displayTitle: String {
        guard let title, !title.isEmpty else { return "Unidentified song" }
        return title
    }

    var displayArtist: String? {
        guard let artist, !artist.isEmpty else { return nil }
        return artist
    }
}
