import Foundation

struct Program: Identifiable, Codable, Sendable, Hashable {
    let slug: String?
    let name: String
    let broadcasters: String?
    let description: String?
    let defaultFirstAiredGuide: Guide?
    let bannerImageUrl: URL?
    let bannerImageSmall: URL?
    let profileImageUrl: URL?
    let profileImageSmall: URL?
    let archived: Bool?

    var id: String { slug ?? name }

    var hasUsableSlug: Bool { !(slug ?? "").isEmpty }

    /// Programs default to the FM feed when the API omits the guide.
    var guide: Guide { defaultFirstAiredGuide ?? .fm }

    var displayBroadcasters: String? {
        guard let broadcasters, !broadcasters.isEmpty else { return nil }
        return broadcasters.htmlStripped
    }

    var displayDescription: String? {
        guard let description, !description.isEmpty else { return nil }
        return description.htmlStripped
    }

    var artworkURL: URL? {
        profileImageUrl ?? bannerImageUrl ?? profileImageSmall ?? bannerImageSmall
    }
}
