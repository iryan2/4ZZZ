import AVFoundation
import Foundation
import Observation
import ShazamKit

/// Identifies the song currently playing, on demand, by handing a short clip of
/// the station audio to ShazamKit.
///
/// Live streams can't be read as a bounded asset, so a ~8 second clip is pulled
/// from a second connection to the Icecast mount. On-demand episodes are already
/// seekable, so a clip is cut straight from the current position with an
/// `AVMutableComposition`. Neither path touches the microphone.
@MainActor
@Observable
final class TrackIdentifier {
    enum State: Equatable {
        case idle
        case listening
        case matched(TrackMatch)
        case noMatch
        case failed(String)
    }

    private(set) var state: State = .idle

    /// Target length of the clip handed to ShazamKit. The Shazam catalogue only
    /// accepts query signatures between its `minimumQuerySignatureDuration` and
    /// `maximumQuerySignatureDuration` (~3–12 s), so this stays clear of both.
    private let queryDuration: TimeInterval = 8
    private let maxClipWait: TimeInterval = 10

    /// Bytes of MP3 carrying roughly `seconds` of audio at `bitrateKbps`, so a
    /// live clip can be capped by duration rather than a fixed byte count (which
    /// overshoots ShazamKit's maximum query signature length at 128 kbps).
    nonisolated static func byteBudget(bitrateKbps: Int, seconds: TimeInterval) -> Int {
        let bytesPerSecond = Double(max(bitrateKbps, 1)) * 1000 / 8
        return max(1, Int(bytesPerSecond * seconds))
    }

    private var task: Task<Void, Never>?

    func identify(source: PlaybackSource, elapsed: TimeInterval) {
        reset()
        state = .listening

        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let signature: SHSignature
                if source.isLive {
                    signature = try await self.liveSignature(from: source.audioURL)
                } else {
                    signature = try await self.episodeSignature(url: source.audioURL, elapsed: elapsed)
                }

                try Task.checkCancellation()
                try self.validateDuration(of: signature)
                let result = await SHSession().result(from: signature)
                try Task.checkCancellation()
                self.apply(result)
            } catch {
                guard !Task.isCancelled else { return }
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        state = .idle
    }

    // MARK: - Results

    private func apply(_ result: SHSession.Result) {
        switch result {
        case .match(let match):
            state = match.mediaItems.first.map { .matched(TrackMatch(mediaItem: $0)) } ?? .noMatch
        case .noMatch:
            state = .noMatch
        case .error(let error, _):
            state = .failed(Self.message(for: error))
        @unknown default:
            state = .failed("Identification failed")
        }
    }

    /// Rejects a signature ShazamKit can't match before spending a round trip on
    /// it. The catalogue only accepts queries between its minimum and maximum
    /// signature durations (roughly 3–12 s), otherwise it returns error 201.
    private func validateDuration(of signature: SHSignature) throws {
        let catalog = SHSession().catalog
        guard signature.duration >= catalog.minimumQuerySignatureDuration else {
            throw TrackIdentifierError.clipTooShort
        }
        guard signature.duration <= catalog.maximumQuerySignatureDuration else {
            throw TrackIdentifierError.clipTooLong
        }
    }

    private nonisolated static func message(for error: Error) -> String {
        let error = error as NSError
        if error.domain == SHErrorDomain {
            switch SHError.Code(rawValue: error.code) {
            case .signatureInvalid, .signatureDurationInvalid:
                return "Couldn't analyse that audio. Try again."
            case .matchAttemptFailed:
                return "Couldn't reach Shazam. Check your connection and try again."
            case .internalError:
                return "Something went wrong identifying that track. Try again."
            default:
                return error.localizedDescription
            }
        }
        if error.domain == "com.apple.ShazamCore" {
            switch error.code {
            case 101:
                return "Shazam couldn't process that clip. Try again."
            case 102:
                return "Song identification isn't available for this build."
            default:
                return error.localizedDescription
            }
        }
        return error.localizedDescription
    }

    // MARK: - Signature sources

    private func liveSignature(from url: URL) async throws -> SHSignature {
        let clip = try await liveClip(from: url)
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "4zzz-shazam-\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: fileURL) }
        try clip.write(to: fileURL, options: .atomic)
        return try await signature(from: AVURLAsset(url: fileURL))
    }

    /// Reads roughly `queryDuration` seconds of MP3 from the Icecast mount,
    /// stripping the inline ICY metadata blocks the server interleaves. The byte
    /// budget is derived from the stream's declared bitrate so the resulting
    /// signature stays inside ShazamKit's query limits.
    private func liveClip(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.timeoutInterval = maxClipWait + 5

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        let http = response as? HTTPURLResponse
        let metaint = http
            .flatMap { $0.value(forHTTPHeaderField: "icy-metaint") }
            .flatMap(Int.init) ?? 0
        let bitrate = http
            .flatMap { $0.value(forHTTPHeaderField: "icy-br") }
            .flatMap(Int.init) ?? 128
        let maxClipBytes = Self.byteBudget(bitrateKbps: bitrate, seconds: queryDuration)

        var audio = Data()
        audio.reserveCapacity(maxClipBytes)
        let deadline = Date().addingTimeInterval(maxClipWait)
        var sinceMetadata = 0
        var metadataRemaining = 0

        for try await byte in bytes {
            if metadataRemaining > 0 {
                metadataRemaining -= 1
                continue
            }
            if metaint > 0, sinceMetadata == metaint {
                metadataRemaining = Int(byte) * 16
                sinceMetadata = 0
                continue
            }
            audio.append(byte)
            sinceMetadata += 1

            if audio.count >= maxClipBytes || Date() > deadline { break }
        }

        guard !audio.isEmpty else { throw TrackIdentifierError.noAudio }
        return audio
    }

    /// Cuts a clip starting at the listener's current position from the single,
    /// seekable on-demand recording.
    private func episodeSignature(url: URL, elapsed: TimeInterval) async throws -> SHSignature {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)

        let start = CMTime(seconds: max(0, elapsed), preferredTimescale: 600)
        let remaining = CMTimeSubtract(duration, start)
        let length = CMTimeMinimum(
            CMTime(seconds: queryDuration, preferredTimescale: 600),
            remaining
        )
        guard length.isNumeric, length.seconds > 0.5 else { throw TrackIdentifierError.noAudio }

        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let sourceTrack = audioTracks.first else { throw TrackIdentifierError.noAudio }

        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else { throw TrackIdentifierError.noAudio }

        try compositionTrack.insertTimeRange(
            CMTimeRange(start: start, duration: length),
            of: sourceTrack,
            at: .zero
        )

        return try await signature(from: composition)
    }

    private func signature(from asset: AVAsset) async throws -> SHSignature {
        try await withCheckedThrowingContinuation { continuation in
            SHSignatureGenerator.generateSignature(from: asset) { signature, error in
                if let signature {
                    continuation.resume(returning: signature)
                } else {
                    continuation.resume(throwing: error ?? TrackIdentifierError.signatureFailed)
                }
            }
        }
    }
}

enum TrackIdentifierError: LocalizedError {
    case noAudio
    case signatureFailed
    case clipTooShort
    case clipTooLong

    var errorDescription: String? {
        switch self {
        case .noAudio, .clipTooShort: return "Not enough audio to identify. Try again."
        case .signatureFailed, .clipTooLong: return "The audio couldn't be analysed."
        }
    }
}
