import Testing
@testable import FourZZZ

@Suite("Interruption resume")
struct InterruptionResumeTests {
    @Test("Resumes after an interruption that ended while the user still wants playback")
    func resumesWhilePlaying() {
        #expect(
            InterruptionResumePolicy.shouldResume(
                wasPlayingBeforeInterruption: true,
                wantsToPlay: true
            )
        )
    }

    @Test("Does not resume after an interruption that began while idle")
    func ignoresIdleStart() {
        #expect(
            !InterruptionResumePolicy.shouldResume(
                wasPlayingBeforeInterruption: false,
                wantsToPlay: true
            )
        )
    }

    @Test("A manual pause during the interruption suppresses the resume")
    func honoursManualPause() {
        #expect(
            !InterruptionResumePolicy.shouldResume(
                wasPlayingBeforeInterruption: true,
                wantsToPlay: false
            )
        )
    }

    @Test("Does not resume when idle and paused")
    func ignoresIdlePause() {
        #expect(
            !InterruptionResumePolicy.shouldResume(
                wasPlayingBeforeInterruption: false,
                wantsToPlay: false
            )
        )
    }
}
