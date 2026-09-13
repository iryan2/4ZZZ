import AVFoundation
import MediaPlayer
import Observation
import UIKit

@MainActor
@Observable
final class PlaybackCoordinator {
    enum State: Equatable {
        case idle
        case loading
        case playing
        case paused
        case failed(String)
    }

    enum SleepTimerOption: Equatable {
        case off
        case minutes(Int)
        case endOfEpisode

        var title: String {
            switch self {
            case .off: return "Off"
            case .minutes(let minutes): return "\(minutes) minutes"
            case .endOfEpisode: return "End of episode"
            }
        }
    }

    private(set) var source: PlaybackSource?
    private(set) var state: State = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval?
    private(set) var sleepTimer: SleepTimerOption = .off
    private(set) var sleepTimerEndsAt: Date?
    private(set) var sleepTimerRemaining: TimeInterval?

    var isLive: Bool { source?.isLive ?? false }
    var canSeek: Bool { source != nil && !isLive }

    private let player = AVPlayer()
    private let nowPlaying = NowPlayingCenter()
    private let artworkLoader = ArtworkLoader()
    private let liveActivity = LiveActivityController()
    private let audioSession = AVAudioSession.sharedInstance()
    private let sleepFadeDuration: TimeInterval = 10

    private var wantsToPlay = false
    private var wasPlayingBeforeInterruption = false
    private var isInterrupted = false
    private var interruptionResumeTask: Task<Void, Never>?
    private var artworkURL: URL?
    private var currentArtwork: UIImage?
    private var reconnectAttempt = 0
    private var pendingSeek: TimeInterval?
    private var lastProgressSave = Date.distantPast
    private var ticker: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init() {
        configureAudioSession()
        configureNowPlaying()
        configureNotifications()
        startTicker()
    }

    isolated deinit {
        ticker?.cancel()
        interruptionResumeTask?.cancel()
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
    }

    // MARK: - Public controls

    func play(_ source: PlaybackSource) {
        self.source = source
        self.artworkURL = source.artworkURL
        self.currentArtwork = nil
        self.elapsed = 0
        self.duration = nil
        self.reconnectAttempt = 0
        self.wantsToPlay = true
        cancelSleepTimer()

        let item = AVPlayerItem(url: source.audioURL)
        player.replaceCurrentItem(with: item)

        if let saved = LibraryStore.shared.savedPosition(for: source), saved > 15 {
            pendingSeek = saved
        } else {
            pendingSeek = nil
        }
        lastProgressSave = .distantPast

        activateAudioSession()
        player.play()
        state = .loading

        loadArtwork()
        updateNowPlaying()
        updateLiveActivity()
    }

    func resume() {
        guard source != nil else { return }
        wantsToPlay = true
        activateAudioSession()
        player.play()
        state = .loading
        updateNowPlaying()
        updateLiveActivity()
    }

    func pause() {
        wantsToPlay = false
        player.pause()
        state = source == nil ? .idle : .paused
        persistProgress()
        updateNowPlaying()
        updateLiveActivity()
    }

    func togglePlayPause() {
        if wantsToPlay {
            pause()
        } else {
            resume()
        }
    }

    @discardableResult
    func seek(to seconds: TimeInterval) -> Bool {
        guard canSeek else { return false }
        let upperBound = duration ?? seconds
        let target = min(max(0, seconds), upperBound)
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        elapsed = target
        updateNowPlaying()
        return true
    }

    @discardableResult
    func skip(by seconds: TimeInterval) -> Bool {
        let current = player.currentTime().seconds
        guard current.isFinite else { return false }
        return seek(to: current + seconds)
    }

    func setSleepTimer(_ option: SleepTimerOption) {
        player.volume = 1
        sleepTimer = option
        switch option {
        case .off:
            sleepTimerEndsAt = nil
            sleepTimerRemaining = nil
        case .minutes(let minutes):
            sleepTimerEndsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
            sleepTimerRemaining = TimeInterval(minutes * 60)
        case .endOfEpisode:
            sleepTimerEndsAt = nil
            sleepTimerRemaining = nil
        }
    }

    func cancelSleepTimer() {
        setSleepTimer(.off)
    }

    // MARK: - Setup

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, policy: .longFormAudio)
        } catch {
            state = .failed("Audio session error: \(error.localizedDescription)")
        }
    }

    private func activateAudioSession() {
        do {
            try audioSession.setActive(true)
        } catch {
            state = .failed("Audio session error: \(error.localizedDescription)")
        }
    }

    private func configureNowPlaying() {
        nowPlaying.onCommand = { [weak self] command in
            guard let self else { return }
            switch command {
            case .play:
                self.resume()
            case .pause:
                self.pause()
            case .togglePlayPause:
                self.togglePlayPause()
            case .skipForward(let interval):
                self.skip(by: interval)
            case .skipBackward(let interval):
                self.skip(by: -interval)
            }
        }
    }

    private func configureNotifications() {
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: AVAudioSession.interruptionNotification,
                object: audioSession,
                queue: .main
            ) { [weak self] notification in
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                MainActor.assumeIsolated {
                    self?.handleInterruption(typeRawValue: rawType)
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: audioSession,
                queue: .main
            ) { [weak self] notification in
                let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
                MainActor.assumeIsolated {
                    self?.handleRouteChange(reasonRawValue: rawReason)
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVPlayerItem.didPlayToEndTimeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleDidPlayToEnd()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: AVPlayerItem.failedToPlayToEndTimeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleItemFailure()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.persistProgress()
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.handleAppBecameActive()
                }
            }
        )
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refresh()
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    // MARK: - State refresh

    private func refresh() {
        guard let item = player.currentItem else {
            elapsed = 0
            return
        }

        let itemDuration = item.duration
        if itemDuration.isNumeric, itemDuration.seconds.isFinite, itemDuration.seconds > 0 {
            duration = itemDuration.seconds
        }

        let current = player.currentTime().seconds
        elapsed = current.isFinite ? current : 0

        if item.status == .failed {
            handleFailure()
            return
        }

        if let seekTarget = pendingSeek, item.status == .readyToPlay {
            pendingSeek = nil
            let upperBound = duration ?? seekTarget
            let target = min(max(0, seekTarget), upperBound)
            player.seek(
                to: CMTime(seconds: target, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            elapsed = target
        }

        if wantsToPlay {
            if isInterrupted {
                state = .paused
            } else if player.timeControlStatus == .playing {
                state = .playing
                reconnectAttempt = 0
            } else {
                state = .loading
            }
        } else {
            state = source == nil ? .idle : .paused
        }

        updateSleepTimer()
        persistProgressIfDue()
        updateNowPlaying()
    }

    /// Records progress at most every 5 seconds while a recording plays.
    private func persistProgressIfDue() {
        guard canSeek, let duration, duration > 0 else { return }
        guard Date().timeIntervalSince(lastProgressSave) >= 5 else { return }
        lastProgressSave = Date()
        recordProgress(completed: elapsed >= duration - 15)
    }

    private func recordProgress(completed: Bool) {
        guard let source, let duration, duration > 0 else { return }
        LibraryStore.shared.recordProgress(
            source: source,
            position: elapsed,
            duration: duration,
            completed: completed
        )
    }

    func persistProgress() {
        guard canSeek, let duration, duration > 0 else { return }
        recordProgress(completed: elapsed >= duration - 15)
        LibraryStore.shared.saveNow()
    }

    private func updateSleepTimer() {
        guard let endsAt = sleepTimerEndsAt else { return }

        let remaining = endsAt.timeIntervalSinceNow
        sleepTimerRemaining = max(0, remaining)

        if remaining <= sleepFadeDuration {
            player.volume = Float(max(0, remaining / sleepFadeDuration))
        } else {
            player.volume = 1
        }

        if remaining <= 0 {
            finishSleepTimer()
        }
    }

    private func finishSleepTimer() {
        pause()
        player.volume = 1
        sleepTimer = .off
        sleepTimerEndsAt = nil
        sleepTimerRemaining = nil
    }

    // MARK: - Event handling

    private func handleInterruption(typeRawValue: UInt?) {
        guard
            let typeRawValue,
            let type = AVAudioSession.InterruptionType(rawValue: typeRawValue)
        else { return }

        switch type {
        case .began:
            isInterrupted = true
            wasPlayingBeforeInterruption = wantsToPlay
        case .ended:
            isInterrupted = false
            if InterruptionResumePolicy.shouldResume(
                wasPlayingBeforeInterruption: wasPlayingBeforeInterruption,
                wantsToPlay: wantsToPlay
            ) {
                resumeAfterInterruption()
            } else {
                wasPlayingBeforeInterruption = false
            }
        @unknown default:
            break
        }
    }

    /// Some interruptions begin without ever posting a matching `.ended`
    /// notification — Siri included. Retry the pending resume when the app
    /// becomes active again.
    private func handleAppBecameActive() {
        guard wasPlayingBeforeInterruption else { return }
        resumeAfterInterruption()
    }

    /// Reactivates the audio session and resumes playback after an interruption.
    ///
    /// The interrupting app's session (Siri's, for example) can still be
    /// deactivating when the interruption ends, so activation is attempted after
    /// a short delay with one retry. The pending-resume flag is only cleared once
    /// playback has actually restarted, so a later `.ended` can still recover it.
    private func resumeAfterInterruption() {
        interruptionResumeTask?.cancel()
        interruptionResumeTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for delay in [Duration.milliseconds(250), .milliseconds(750)] {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                guard self.wantsToPlay, self.source != nil else {
                    self.wasPlayingBeforeInterruption = false
                    self.isInterrupted = false
                    return
                }

                do {
                    try self.audioSession.setActive(true)
                } catch {
                    continue
                }

                self.player.play()
                self.state = .loading
                self.wasPlayingBeforeInterruption = false
                self.isInterrupted = false
                self.updateNowPlaying()
                self.updateLiveActivity()
                return
            }
        }
    }

    private func handleRouteChange(reasonRawValue: UInt?) {
        guard
            let reasonRawValue,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRawValue)
        else { return }

        if reason == .oldDeviceUnavailable {
            pause()
        }
    }

    private func handleDidPlayToEnd() {
        wantsToPlay = false
        if let duration {
            elapsed = duration
        }
        state = .paused
        if sleepTimer == .endOfEpisode {
            finishSleepTimer()
        }
        if canSeek, let duration, duration > 0 {
            recordProgress(completed: true)
            LibraryStore.shared.saveNow()
        }
        updateNowPlaying()
        updateLiveActivity()
        if !isLive {
            Task { await liveActivity.end() }
        }
    }

    private func handleItemFailure() {
        handleFailure()
    }

    private func handleFailure() {
        guard case .live(let guide) = source else {
            state = .failed("Playback failed")
            return
        }

        state = .loading
        let attempt = reconnectAttempt
        reconnectAttempt += 1
        let delay = min(pow(2.0, Double(attempt)), 15)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.wantsToPlay else { return }
            self.play(.live(guide))
            self.reconnectAttempt = attempt + 1
        }
    }

    // MARK: - Now Playing

    private func loadArtwork() {
        guard let artworkURL else {
            updateNowPlaying()
            return
        }
        Task { @MainActor [weak self] in
            let image = await self?.artworkLoader.image(for: artworkURL)
            guard let self, self.artworkURL == artworkURL else { return }
            self.currentArtwork = image
            self.updateNowPlaying()
            self.updateLiveActivity()
        }
    }

    private func updateLiveActivity() {
        liveActivity.update(
            source: source,
            isPlaying: wantsToPlay,
            elapsed: elapsed,
            duration: duration,
            artwork: currentArtwork
        )
    }

    private func updateNowPlaying() {
        guard let source else {
            nowPlaying.clear()
            return
        }

        let title: String
        let artist: String
        switch source {
        case .live(let guide):
            title = "Live — \(guide.displayName)"
            artist = "4ZZZ"
        case .episode(_, let showName, _, let episodeTitle, _, _, _):
            title = episodeTitle ?? showName
            artist = showName
        }

        let artwork = currentArtwork.map(Self.makeArtwork)

        nowPlaying.setSkipEnabled(canSeek)
        nowPlaying.update(
            title: title,
            artist: artist,
            albumTitle: "4ZZZ",
            artwork: artwork,
            isLive: source.isLive,
            duration: source.isLive ? nil : duration,
            elapsed: elapsed,
            rate: wantsToPlay ? 1 : 0
        )
    }

    /// `MPMediaItemArtwork` may invoke its request handler on MediaPlayer's own
    /// queue, so it must not be actor-isolated.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}
