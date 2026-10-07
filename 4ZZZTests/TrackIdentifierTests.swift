import Foundation
import Testing
@testable import FourZZZ

@Suite("Track identifier")
struct TrackIdentifierTests {
    @Test("Derives a clip byte budget from the stream's declared bitrate")
    func byteBudget() {
        #expect(TrackIdentifier.byteBudget(bitrateKbps: 128, seconds: 8) == 128_000)
        #expect(TrackIdentifier.byteBudget(bitrateKbps: 64, seconds: 8) == 64_000)
    }

    @Test("Falls back to a usable budget for a missing or invalid bitrate")
    func byteBudgetFallback() {
        #expect(TrackIdentifier.byteBudget(bitrateKbps: 0, seconds: 8) == 1_000)
        #expect(TrackIdentifier.byteBudget(bitrateKbps: -5, seconds: 8) == 1_000)
    }
}
