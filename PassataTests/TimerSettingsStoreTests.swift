import XCTest
@testable import Passata

@MainActor
final class TimerSettingsStoreTests: XCTestCase {
    func testEngineUsesChangedSettingsForResetAndNextPhaseDurations() {
        let persister = SettingsSpy()
        let store = TimerSettingsStore(persister: persister)
        let engine = TimerEngine(durationProvider: store, persister: NoOpTimerStateStore())
        store.engine = engine
        XCTAssertEqual(engine.remainingSeconds, 25 * 60)

        engine.start()
        store.adjustDuration(\.focusMinutes, delta: 5, in: 5...90, affecting: .focus)
        XCTAssertEqual(engine.remainingSeconds, 25 * 60)
        engine.onReset()
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.remainingSeconds, 30 * 60)
        XCTAssertEqual(engine.currentRenderState, .idle(phaseDurationSeconds: 30 * 60))

        store.adjustDuration(\.shortBreakMinutes, delta: 2, in: 1...30, affecting: .shortBreak)
        engine.onStartNext()
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(engine.remainingSeconds, 7 * 60)
        if case let .running(start, end) = engine.currentRenderState {
            XCTAssertEqual(end.timeIntervalSince(start), 420)
        } else {
            XCTFail("Expected the next phase to have a running interval")
        }
        XCTAssertEqual(persister.stored?.durations,
                       PhaseDurations(focusMinutes: 30, shortBreakMinutes: 7, longBreakMinutes: 15))
    }

    func testAdjustDurationClampsEveryFieldAndSetsCustomPreset() {
        let store = makeStore()

        store.adjustDuration(\.focusMinutes, delta: -100, in: 5...90, affecting: .focus)
        XCTAssertEqual(store.settings.durations.focusMinutes, 5)
        store.adjustDuration(\.focusMinutes, delta: 100, in: 5...90, affecting: .focus)
        XCTAssertEqual(store.settings.durations.focusMinutes, 90)

        store.adjustDuration(\.shortBreakMinutes, delta: -100, in: 1...30, affecting: .shortBreak)
        XCTAssertEqual(store.settings.durations.shortBreakMinutes, 1)
        store.adjustDuration(\.shortBreakMinutes, delta: 100, in: 1...30, affecting: .shortBreak)
        XCTAssertEqual(store.settings.durations.shortBreakMinutes, 30)

        store.adjustDuration(\.longBreakMinutes, delta: -100, in: 5...60, affecting: .longBreak)
        XCTAssertEqual(store.settings.durations.longBreakMinutes, 5)
        store.adjustDuration(\.longBreakMinutes, delta: 100, in: 5...60, affecting: .longBreak)
        XCTAssertEqual(store.settings.durations.longBreakMinutes, 60)
        XCTAssertEqual(store.settings.preset, .custom)
    }

    func testCyclePresetAppliesPresetDurationsAndCustomPreservesThem() {
        let store = makeStore()

        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .deep)
        XCTAssertEqual(store.settings.durations, .init(focusMinutes: 50, shortBreakMinutes: 10, longBreakMinutes: 30))

        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .short)
        XCTAssertEqual(store.settings.durations, .init(focusMinutes: 15, shortBreakMinutes: 3, longBreakMinutes: 15))

        let shortDurations = store.settings.durations
        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .custom)
        XCTAssertEqual(store.settings.durations, shortDurations)

        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .classic)
        XCTAssertEqual(store.settings.durations, .init(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15))
    }

    func testAdjustDurationSyncsTheIdleEngineButNotRunningOrPausedEngine() {
        let engine = makeEngine()
        let store = makeStore(engine: engine)

        store.adjustDuration(\.focusMinutes, delta: 5, in: 5...90, affecting: .focus)
        XCTAssertEqual(engine.remainingSeconds, 30 * 60)

        engine.start()
        let runningRemaining = engine.remainingSeconds
        store.adjustDuration(\.focusMinutes, delta: 5, in: 5...90, affecting: .focus)
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(engine.remainingSeconds, runningRemaining)

        engine.pause()
        let pausedRemaining = engine.remainingSeconds
        store.adjustDuration(\.focusMinutes, delta: 5, in: 5...90, affecting: .focus)
        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.remainingSeconds, pausedRemaining)
    }

    func testCyclePresetSyncsTheIdleEngineButNotRunningOrPausedEngine() {
        let engine = makeEngine()
        let store = makeStore(engine: engine)

        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .deep)
        XCTAssertEqual(engine.remainingSeconds, 50 * 60)

        engine.start()
        let runningRemaining = engine.remainingSeconds
        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .short)
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(engine.remainingSeconds, runningRemaining)

        engine.pause()
        let pausedRemaining = engine.remainingSeconds
        store.cyclePreset()
        XCTAssertEqual(store.settings.preset, .custom)
        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.remainingSeconds, pausedRemaining)
    }

    func testInitAppliesPersistedAutoStartSettingToEngine() {
        let persister = SettingsSpy()
        var persistedSettings = TimerSettings()
        persistedSettings.autoStartNext = false
        persister.stored = persistedSettings
        let engine = makeEngine()

        _ = TimerSettingsStore(persister: persister, engine: engine)

        XCTAssertFalse(engine.autoStartNext)
    }

    func testTogglesPersistTheirNewValues() {
        let persister = SettingsSpy()
        let engine = makeEngine()
        let store = TimerSettingsStore(persister: persister, engine: engine)

        store.toggleSound()
        var expected = TimerSettings()
        expected.soundOn = false
        XCTAssertEqual(persister.stored, expected)
        store.toggleHaptics()
        expected.hapticsOn = false
        XCTAssertEqual(persister.stored, expected)
        store.toggleAutoStart()
        expected.autoStartNext = false
        XCTAssertEqual(persister.stored, expected)

        XCTAssertFalse(store.settings.soundOn)
        XCTAssertFalse(store.settings.hapticsOn)
        XCTAssertFalse(store.settings.autoStartNext)
        XCTAssertFalse(engine.autoStartNext)
        XCTAssertEqual(persister.saveCount, 3)
    }

    private func makeStore(engine: TimerEngine? = nil) -> TimerSettingsStore {
        TimerSettingsStore(persister: SettingsSpy(), engine: engine)
    }

    private func makeEngine() -> TimerEngine {
        TimerEngine(durationProvider: FixedDurationProvider(), persister: NoOpTimerStateStore())
    }
}

private struct FixedDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int { 120 }
}

private final class SettingsSpy: SettingsPersisting {
    var stored: TimerSettings?
    var saveCount = 0
    func load() -> TimerSettings? { stored }
    func save(_ settings: TimerSettings) { stored = settings; saveCount += 1 }
}
