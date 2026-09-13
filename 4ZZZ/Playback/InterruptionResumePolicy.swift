import Foundation

/// Pure decision logic for whether playback should resume after an
/// audio-session interruption. Kept free of AVFoundation so it can be tested.
///
/// The system's `.shouldResume` interruption option is intentionally *not* part
/// of this decision: Siri (and some other transient interruptions) end without
/// it, yet Apple documents the flag as a hint that apps which don't require user
/// input to begin playback may disregard. A manual pause during the interruption
/// clears `wantsToPlay`, which still suppresses the resume.
enum InterruptionResumePolicy {
    static func shouldResume(
        wasPlayingBeforeInterruption: Bool,
        wantsToPlay: Bool
    ) -> Bool {
        wasPlayingBeforeInterruption && wantsToPlay
    }
}
