import Foundation
import MediaPlayer

@MainActor
final class NowPlayingCenter {
    enum Command: Sendable {
        case play
        case pause
        case togglePlayPause
        case skipForward(TimeInterval)
        case skipBackward(TimeInterval)
    }

    var onCommand: (@MainActor (Command) -> Void)?

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let infoCenter = MPNowPlayingInfoCenter.default()
    private var retainedTargets: [(MPRemoteCommand, Any)] = []

    init() {
        configureCommands()
    }

    private func configureCommands() {
        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.preferredIntervals = [30]

        add(commandCenter.playCommand) { .play }
        add(commandCenter.pauseCommand) { .pause }
        add(commandCenter.togglePlayPauseCommand) { .togglePlayPause }
        add(commandCenter.skipForwardCommand) { .skipForward(30) }
        add(commandCenter.skipBackwardCommand) { .skipBackward(30) }
    }

    private func add(
        _ command: MPRemoteCommand,
        _ makeCommand: @escaping @MainActor () -> Command
    ) {
        let token = command.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.onCommand?(makeCommand())
            }
            return .success
        }
        retainedTargets.append((command, token))
    }

    func setSkipEnabled(_ enabled: Bool) {
        commandCenter.skipForwardCommand.isEnabled = enabled
        commandCenter.skipBackwardCommand.isEnabled = enabled
    }

    func update(
        title: String,
        artist: String,
        albumTitle: String?,
        artwork: MPMediaItemArtwork?,
        isLive: Bool,
        duration: TimeInterval?,
        elapsed: TimeInterval,
        rate: Float
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyIsLiveStream: isLive,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        if let duration, duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        infoCenter.nowPlayingInfo = info
    }

    func clear() {
        infoCenter.nowPlayingInfo = nil
    }
}
