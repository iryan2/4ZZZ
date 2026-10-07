import Foundation
import ShazamKit
import Testing
@testable import FourZZZ

@Suite("Track match")
struct TrackMatchTests {
    @Test("Maps a Shazam media item into display fields")
    func mapsMediaItem() throws {
        let artwork = try #require(URL(string: "https://example.com/art.jpg"))
        let appleMusic = try #require(URL(string: "https://music.apple.com/song/1"))
        let item = SHMediaItem(properties: [
            .title: "Blowin' Up",
            .artist: "Dinosaur Jr.",
            .artworkURL: artwork,
            .appleMusicURL: appleMusic,
            .genres: ["Rock"],
        ])

        let match = TrackMatch(mediaItem: item)
        #expect(match.title == "Blowin' Up")
        #expect(match.artist == "Dinosaur Jr.")
        #expect(match.artworkURL == artwork)
        #expect(match.appleMusicURL == appleMusic)
        #expect(match.genres == ["Rock"])
        #expect(match.displayTitle == "Blowin' Up")
        #expect(match.displayArtist == "Dinosaur Jr.")
    }

    @Test("Falls back when a match has no title or artist")
    func missingFields() {
        let match = TrackMatch(mediaItem: SHMediaItem(properties: [:]))
        #expect(match.displayTitle == "Unidentified song")
        #expect(match.displayArtist == nil)
    }
}
