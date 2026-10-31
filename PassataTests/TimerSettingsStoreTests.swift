import Foundation
import XCTest
@testable import Passata

@MainActor
final class TimerSettingsStoreTests: XCTestCase {
    func testDurationParserAcceptsSupportedFormsAndBounds() {
        let validInputs: [(String, Int)] = [
            ("3:30", 210), ("3.5", 210), ("3,5", 210), ("25", 1_500),
            ("3:5", 185), ("0:30", DurationBounds.focus.lowerBound),
            ("180:00", DurationBounds.focus.upperBound), (" 3:30 ", 210)
        ]
        for (input, expectedSeconds) in validInputs {
            XCTAssertEqual(DurationInputParsing.seconds(from: input, bounds: DurationBounds.focus), expectedSeconds, input)
        }

        let invalidInputs = [
            "", " ", "inf", "nan", "1e300", "1e1", "0x1A", "-1", "3:99", "3::30", "3:", ":30",
            "3.5:30", "3:30.5", "1,5:00", "200000000000000000:00", "0:29", "180:01"
        ]
        for input in invalidInputs {
            XCTAssertNil(DurationInputParsing.seconds(from: input, bounds: DurationBounds.focus), input)
        }
    }

    func testRejectedTypedDurationLeavesSettingsAndPersistenceUnchanged() {
        let persister = SettingsSpy()
        let store = TimerSettingsStore(persister: persister)
        let originalSettings = store.settings

        XCTAssertFalse(store.typeDuration("3:30.5", affecting: .focus))
        XCTAssertFalse(store.typeDuration("180:01", affecting: .focus))

        XCTAssertEqual(store.settings, originalSettings)
        XCTAssertEqual(persister.saveCount, 0)
    }

    func testSessionsPerCycleParserAcceptsOnlyWholeNumbersWithinBounds() {
        XCTAssertEqual(DurationInputParsing.sessionsPerCycle(from: "1", bounds: DurationBounds.sessionsPerCycle), 1)
        XCTAssertEqual(DurationInputParsing.sessionsPerCycle(from: "12", bounds: DurationBounds.sessionsPerCycle), 12)
        for input in ["", "0", "13", "2.0", "2:00", "1e1", "999999999999999999999999999999"] {
            XCTAssertNil(DurationInputParsing.sessionsPerCycle(from: input, bounds: DurationBounds.sessionsPerCycle), input)
        }
    }

    func testDurationSettingLabelsUseMinutesOrMinuteSecondForm() {
        XCTAssertEqual(1_500.asDurationSettingLabel, "25 min")
        XCTAssertEqual(210.asDurationSettingLabel, "3:30")
        XCTAssertEqual(30.asDurationSettingLabel, "0:30")
        XCTAssertEqual(1_500.asDurationInputString, "25")
        XCTAssertEqual(210.asDurationInputString, "3:30")
    }

    func testTypedFocusDurationRunsForTheParsedNumberOfSeconds() {
        let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 1_000))
        let store = TimerSettingsStore(persister: SettingsSpy())
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: clock,
            persister: SettingsTestTimerStateStore(),
            autoStartNext: false
        )
        store.engine = engine

        XCTAssertTrue(store.typeDuration("3:30", affecting: .focus))
        XCTAssertEqual(engine.remainingSeconds, 210)
        XCTAssertEqual(engine.currentPhaseDuration, 210)
        engine.start()
        guard case let .running(phaseStart, phaseEnd) = engine.currentRenderState else {
            return XCTFail("The typed duration should start a running phase")
        }
        XCTAssertEqual(phaseStart, clock.now)
        XCTAssertEqual(phaseEnd, clock.now.addingTimeInterval(210))

        clock.now = phaseEnd
        engine.checkForCompletion()
        XCTAssertEqual(engine.status, .complete)
        XCTAssertEqual(engine.remainingSeconds, 0)
    }

    func testSteppersClampAllDurationsAndSessionsAndUseOneMinuteSteps() {
        let store = TimerSettingsStore(persister: SettingsSpy())
        store.adjustDuration(\.focusSeconds, delta: DurationBounds.stepSeconds, in: DurationBounds.focus, affecting: .focus)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_560)
        store.adjustDuration(\.focusSeconds, delta: -10_000, in: DurationBounds.focus, affecting: .focus)
        XCTAssertEqual(store.settings.durations.focusSeconds, DurationBounds.focus.lowerBound)
        store.adjustDuration(\.focusSeconds, delta: 100_000, in: DurationBounds.focus, affecting: .focus)
        XCTAssertEqual(store.settings.durations.focusSeconds, DurationBounds.focus.upperBound)

        store.adjustDuration(\.shortBreakSeconds, delta: -10_000, in: DurationBounds.shortBreak, affecting: .shortBreak)
        XCTAssertEqual(store.settings.durations.shortBreakSeconds, DurationBounds.shortBreak.lowerBound)
        store.adjustDuration(\.shortBreakSeconds, delta: 100_000, in: DurationBounds.shortBreak, affecting: .shortBreak)
        XCTAssertEqual(store.settings.durations.shortBreakSeconds, DurationBounds.shortBreak.upperBound)

        store.adjustDuration(\.longBreakSeconds, delta: -10_000, in: DurationBounds.longBreak, affecting: .longBreak)
        XCTAssertEqual(store.settings.durations.longBreakSeconds, DurationBounds.longBreak.lowerBound)
        store.adjustDuration(\.longBreakSeconds, delta: 100_000, in: DurationBounds.longBreak, affecting: .longBreak)
        XCTAssertEqual(store.settings.durations.longBreakSeconds, DurationBounds.longBreak.upperBound)

        store.adjustSessionsPerCycle(by: -100)
        XCTAssertEqual(store.sessionsPerCycle, DurationBounds.sessionsPerCycle.lowerBound)
        store.adjustSessionsPerCycle(by: 100)
        XCTAssertEqual(store.sessionsPerCycle, DurationBounds.sessionsPerCycle.upperBound)
    }

    func testDurationChangeRuleOnlyGatesChangesToTheActivePhaseWhileRunningOrPaused() {
        for status: RunStatus in [.idle, .complete] {
            XCTAssertFalse(DurationChangeRule.requiresConfirmation(
                changing: .focus, to: 1_560, enginePhase: .focus, status: status, capturedDuration: 1_500
            ))
        }
        XCTAssertFalse(DurationChangeRule.requiresConfirmation(
            changing: .shortBreak, to: 420, enginePhase: .focus, status: .running, capturedDuration: 1_500
        ))
        XCTAssertFalse(DurationChangeRule.requiresConfirmation(
            changing: .focus, to: 1_500, enginePhase: .focus, status: .paused, capturedDuration: 1_500
        ))
        XCTAssertTrue(DurationChangeRule.requiresConfirmation(
            changing: .focus, to: 1_560, enginePhase: .focus, status: .running, capturedDuration: 1_500
        ))
        XCTAssertTrue(DurationChangeRule.requiresConfirmation(
            changing: .focus, to: 1_560, enginePhase: .focus, status: .paused, capturedDuration: 1_500
        ))
        XCTAssertFalse(DurationChangeRule.requiresConfirmation(
            changing: .focus,
            to: 1_560,
            enginePhase: .focus,
            status: .running,
            capturedDuration: 1_500,
            hasRememberedDecision: true
        ))
    }

    func testRestartChoiceIsRememberedForTheCurrentPhaseOccurrence() {
        let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 2_000))
        let store = TimerSettingsStore(persister: SettingsSpy())
        let statePersister = SettingsTestTimerStateStore()
        let engine = TimerEngine(durationProvider: store, dateProvider: clock, persister: statePersister)
        store.engine = engine
        engine.start()

        XCTAssertTrue(store.typeDuration("26", affecting: .focus))
        XCTAssertNotNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_500)
        store.resolvePendingDurationChange(restartCurrentPhase: true)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_560)
        XCTAssertEqual(engine.currentPhaseDuration, 1_560)
        XCTAssertEqual(engine.remainingSeconds, 1_560)

        clock.now = clock.now.addingTimeInterval(10)
        XCTAssertTrue(store.typeDuration("27", affecting: .focus))
        XCTAssertNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_620)
        XCTAssertEqual(engine.currentPhaseDuration, 1_620)
        XCTAssertEqual(engine.remainingSeconds, 1_620)
        XCTAssertEqual(statePersister.latest?.phaseDuration, 1_620)
        XCTAssertEqual(statePersister.latest?.endDate, clock.now.addingTimeInterval(1_620))

        clock.now = clock.now.addingTimeInterval(10)
        XCTAssertTrue(store.typeDuration("28", affecting: .focus))
        XCTAssertNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_680)
        XCTAssertEqual(engine.currentPhaseDuration, 1_680)
        XCTAssertEqual(engine.remainingSeconds, 1_680)
        XCTAssertEqual(statePersister.latest?.endDate, clock.now.addingTimeInterval(1_680))

        store.resetToDefaults()
        XCTAssertNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations, .classic)
        XCTAssertEqual(engine.currentPhaseDuration, PhaseDurations.classic.focusSeconds)
        XCTAssertEqual(engine.remainingSeconds, PhaseDurations.classic.focusSeconds)
    }

    func testApplyNextChoiceIsRememberedForTheCurrentPausedOccurrence() {
        let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 2_100))
        let store = TimerSettingsStore(persister: SettingsSpy())
        let engine = TimerEngine(durationProvider: store, dateProvider: clock, persister: SettingsTestTimerStateStore())
        store.engine = engine
        engine.start()
        clock.now = clock.now.addingTimeInterval(30)
        engine.pause()
        let pausedRender = engine.currentRenderState

        XCTAssertTrue(store.typeDuration("26", affecting: .focus))
        XCTAssertNotNil(store.pendingDurationChange)
        store.resolvePendingDurationChange(restartCurrentPhase: false)

        XCTAssertTrue(store.typeDuration("27", affecting: .focus))
        XCTAssertNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_620)
        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.currentPhaseDuration, 1_500)
        XCTAssertEqual(engine.remainingSeconds, 1_470)
        XCTAssertEqual(engine.currentRenderState, pausedRender)
    }

    func testCancellingDurationChangeDoesNotRememberAnAnswer() {
        let store = TimerSettingsStore(persister: SettingsSpy())
        let engine = TimerEngine(durationProvider: store, persister: SettingsTestTimerStateStore())
        store.engine = engine
        engine.start()

        XCTAssertTrue(store.typeDuration("26", affecting: .focus))
        XCTAssertNotNil(store.pendingDurationChange)
        store.cancelPendingDurationChange()

        XCTAssertTrue(store.typeDuration("27", affecting: .focus))
        XCTAssertNotNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.focusSeconds, 1_500)
    }

    func testEachPhaseOccurrenceBoundaryRequiresAConfirmationAgain() {
        let actions: [(String, (TimerEngine, SettingsTestClock) -> Phase)] = [
            ("completion and next phase", { engine, clock in
                clock.now = clock.now.addingTimeInterval(TimeInterval(engine.currentPhaseDuration))
                engine.checkForCompletion()
                XCTAssertEqual(engine.status, .complete)
                engine.onStartNext()
                return engine.phase
            }),
            ("skip", { engine, _ in
                engine.onSkip()
                engine.start()
                return engine.phase
            }),
            ("reset", { engine, _ in
                engine.onReset()
                engine.start()
                return engine.phase
            }),
            ("restart cycle", { engine, _ in
                engine.restartCycle()
                engine.start()
                return engine.phase
            }),
            ("next phase starts", { engine, _ in
                engine.onStartNext()
                return engine.phase
            })
        ]

        for (name, action) in actions {
            let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 2_200))
            let store = TimerSettingsStore(persister: SettingsSpy())
            let engine = TimerEngine(
                durationProvider: store,
                dateProvider: clock,
                persister: SettingsTestTimerStateStore(),
                autoStartNext: false
            )
            store.engine = engine
            engine.start()

            XCTAssertTrue(store.typeDuration("26", affecting: .focus), name)
            XCTAssertNotNil(store.pendingDurationChange, name)
            store.resolvePendingDurationChange(restartCurrentPhase: false)
            XCTAssertNil(store.pendingDurationChange, name)

            let phase = action(engine, clock)
            XCTAssertEqual(engine.status, .running, name)
            let changedDurationInput = switch phase {
            case .focus: "27"
            case .shortBreak: "6"
            case .longBreak: "16"
            }
            XCTAssertTrue(store.typeDuration(changedDurationInput, affecting: phase), name)
            XCTAssertNotNil(store.pendingDurationChange, name)
        }
    }

    func testBackgroundCatchUpStartsANewOccurrenceAndAsksForItsDurationChange() {
        let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 2_300))
        let store = TimerSettingsStore(persister: SettingsSpy())
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: clock,
            persister: SettingsTestTimerStateStore(),
            autoStartNext: true
        )
        store.engine = engine
        engine.start()

        XCTAssertTrue(store.typeDuration("26", affecting: .focus))
        store.resolvePendingDurationChange(restartCurrentPhase: false)
        let completedOccurrenceID = engine.phaseOccurrenceID
        let focusEnd = clock.now.addingTimeInterval(TimeInterval(engine.currentPhaseDuration))
        clock.now = focusEnd.addingTimeInterval(10)

        engine.checkForCompletion()

        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.status, .running)
        XCTAssertEqual(engine.phaseOccurrenceID, completedOccurrenceID + 1)
        XCTAssertTrue(store.typeDuration("6", affecting: .shortBreak))
        XCTAssertNotNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.shortBreakSeconds, 300)
    }

    func testApplyNextSessionPersistsTheCapturedDurationForRelaunch() throws {
        let suite = "PassataTests.CapturedDurationRelaunch." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 2_500))
        let settingsStore = TimerSettingsStore(persister: SettingsSpy())
        let stateStore = UserDefaultsTimerStateStore(defaults: defaults, key: "timer-state")
        let engine = TimerEngine(durationProvider: settingsStore, dateProvider: clock, persister: stateStore)
        settingsStore.engine = engine
        engine.start()

        XCTAssertTrue(settingsStore.typeDuration("26", affecting: .focus))
        settingsStore.resolvePendingDurationChange(restartCurrentPhase: false)

        let reloadedEngine = TimerEngine(durationProvider: settingsStore, dateProvider: clock, persister: stateStore)

        XCTAssertEqual(settingsStore.duration(for: .focus), 1_560)
        XCTAssertEqual(reloadedEngine.status, .running)
        XCTAssertEqual(reloadedEngine.currentPhaseDuration, 1_500)
        XCTAssertEqual(reloadedEngine.remainingSeconds, 1_500)
        XCTAssertEqual(reloadedEngine.currentRenderState, engine.currentRenderState)
    }

    func testRestartingChangedPausedPhaseKeepsItPausedAtNewFullDuration() {
        var persistedSettings = TimerSettings()
        persistedSettings.durations.focusSeconds = 1_800
        let store = TimerSettingsStore(persister: SettingsSpy(stored: persistedSettings))
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 3_000)),
            persister: SettingsTestTimerStateStore()
        )
        store.engine = engine
        engine.start()
        engine.pause()

        XCTAssertTrue(store.typeDuration("25", affecting: .focus))
        store.resolvePendingDurationChange(restartCurrentPhase: true)

        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.remainingSeconds, 1_500)
        XCTAssertEqual(engine.currentPhaseDuration, 1_500)
        XCTAssertEqual(engine.currentRenderState, .paused(remainingSeconds: 1_500, phaseDurationSeconds: 1_500))
    }

    func testApplyingPausedDurationNextSessionKeepsCurrentRenderUnchanged() {
        let clock = SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 3_500))
        let store = TimerSettingsStore(persister: SettingsSpy())
        let engine = TimerEngine(durationProvider: store, dateProvider: clock, persister: SettingsTestTimerStateStore())
        store.engine = engine
        engine.start()
        clock.now = clock.now.addingTimeInterval(30)
        engine.pause()
        let pausedRender = engine.currentRenderState

        XCTAssertTrue(store.typeDuration("26", affecting: .focus))
        XCTAssertNotNil(store.pendingDurationChange)
        store.resolvePendingDurationChange(restartCurrentPhase: false)

        XCTAssertEqual(store.settings.durations.focusSeconds, 1_560)
        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.remainingSeconds, 1_470)
        XCTAssertEqual(engine.currentPhaseDuration, 1_500)
        XCTAssertEqual(engine.currentRenderState, pausedRender)
    }

    func testNonCurrentDurationAndSessionChangesApplyWithoutAConfirmation() {
        let store = TimerSettingsStore(persister: SettingsSpy())
        var transitions: [(TimerEngine.TransitionKind, Phase, RenderState)] = []
        let engine = TimerEngine(
            durationProvider: store,
            persister: SettingsTestTimerStateStore(),
            onStateChange: { phase, _, render, kind in transitions.append((kind, phase, render)) }
        )
        store.engine = engine
        engine.start()
        let currentRender = engine.currentRenderState
        transitions.removeAll()

        XCTAssertTrue(store.typeDuration("7", affecting: .shortBreak))
        XCTAssertEqual(transitions.count, 1)
        XCTAssertEqual(transitions[0].0, .reanchored)
        XCTAssertEqual(transitions[0].1, .focus)
        XCTAssertEqual(transitions[0].2, currentRender)
        transitions.removeAll()
        store.adjustSessionsPerCycle(by: 1)

        XCTAssertNil(store.pendingDurationChange)
        XCTAssertEqual(store.settings.durations.shortBreakSeconds, 420)
        XCTAssertEqual(store.sessionsPerCycle, 5)
        XCTAssertEqual(engine.currentPhaseDuration, 1_500)
        XCTAssertEqual(engine.currentRenderState, currentRender)
        XCTAssertEqual(transitions.count, 1)
        XCTAssertEqual(transitions[0].0, .reanchored)
        XCTAssertEqual(transitions[0].1, .focus)
        XCTAssertEqual(transitions[0].2, currentRender)
    }

    func testResetToDefaultsAppliesAtomicallyAndPreservesUnrelatedToggles() {
        var initialSettings = TimerSettings()
        initialSettings.durations = PhaseDurations(focusSeconds: 1_800, shortBreakSeconds: 420, longBreakSeconds: 1_020)
        initialSettings.sessionsPerCycle = 6
        initialSettings.soundOn = false
        initialSettings.hapticsOn = false
        initialSettings.autoStartNext = false
        initialSettings.respectSilentMode = false
        let persister = SettingsSpy(stored: initialSettings)
        let store = TimerSettingsStore(persister: persister)
        let engine = TimerEngine(durationProvider: store, persister: SettingsTestTimerStateStore())
        store.engine = engine
        engine.start()

        let saveCountBeforeReset = persister.saveCount
        store.resetToDefaults()
        XCTAssertNotNil(store.pendingDurationChange)
        XCTAssertTrue(store.pendingDurationChange?.isResetToDefaults == true)
        XCTAssertEqual(store.settings, initialSettings, "The reset remains atomic until the user confirms")
        XCTAssertEqual(persister.saveCount, saveCountBeforeReset)
        store.cancelPendingDurationChange()
        XCTAssertEqual(store.settings, initialSettings, "Cancel discards the whole reset")
        XCTAssertEqual(persister.saveCount, saveCountBeforeReset)

        store.resetToDefaults()
        store.resolvePendingDurationChange(restartCurrentPhase: false)
        XCTAssertEqual(store.settings.durations, .classic)
        XCTAssertEqual(store.settings.sessionsPerCycle, TimerSettings.classicSessionsPerCycle)
        XCTAssertFalse(store.settings.soundOn)
        XCTAssertFalse(store.settings.hapticsOn)
        XCTAssertFalse(store.settings.autoStartNext)
        XCTAssertFalse(store.settings.respectSilentMode)
        XCTAssertEqual(engine.currentPhaseDuration, 1_800, "Apply Next Session retains the current captured duration")
        XCTAssertEqual(persister.saveCount, saveCountBeforeReset + 1)
    }

    func testResetToDefaultsCanRestartTheCurrentSession() {
        var initialSettings = TimerSettings()
        initialSettings.durations.focusSeconds = 1_800
        let store = TimerSettingsStore(persister: SettingsSpy(stored: initialSettings))
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: SettingsTestClock(now: Date(timeIntervalSinceReferenceDate: 4_000)),
            persister: SettingsTestTimerStateStore()
        )
        store.engine = engine
        engine.start()
        engine.pause()

        store.resetToDefaults()
        store.resolvePendingDurationChange(restartCurrentPhase: true)

        XCTAssertEqual(store.settings.durations, .classic)
        XCTAssertEqual(store.sessionsPerCycle, TimerSettings.classicSessionsPerCycle)
        XCTAssertEqual(engine.status, .paused)
        XCTAssertEqual(engine.currentPhaseDuration, 1_500)
        XCTAssertEqual(engine.remainingSeconds, 1_500)
    }

    func testSessionsPerCycleSettingDrivesEngineProgression() {
        let store = TimerSettingsStore(persister: SettingsSpy())
        let statePersister = SettingsTestTimerStateStore(snapshot: TimerSnapshot(
            phase: .focus, status: .idle, sessionIndex: 2, endDate: nil, pausedRemaining: nil
        ))
        let engine = TimerEngine(durationProvider: store, persister: statePersister)
        store.engine = engine

        XCTAssertTrue(store.typeSessionsPerCycle("2"))
        XCTAssertEqual(engine.sessionsPerCycle, 2)
        engine.onSkip()

        XCTAssertEqual(engine.phase, .longBreak)
        XCTAssertEqual(engine.sessionIndex, 2)
    }

    func testResetToDefaultsWhenIdleUpdatesCurrentEngineDurationImmediately() {
        var settings = TimerSettings()
        settings.durations.focusSeconds = 1_800
        let store = TimerSettingsStore(persister: SettingsSpy(stored: settings))
        let engine = TimerEngine(durationProvider: store, persister: SettingsTestTimerStateStore())
        store.engine = engine

        store.resetToDefaults()

        XCTAssertNil(store.pendingDurationChange)
        XCTAssertEqual(engine.status, .idle)
        XCTAssertEqual(engine.remainingSeconds, 1_500)
        XCTAssertEqual(store.settings.durations, .classic)
    }

    func testTogglesPersistTheirNewValues() {
        let persister = SettingsSpy()
        let engine = makeEngine()
        let store = TimerSettingsStore(persister: persister, engine: engine)

        store.toggleSound()
        store.toggleHaptics()
        store.toggleAutoStart()
        store.toggleRespectSilentMode()

        XCTAssertFalse(store.settings.soundOn)
        XCTAssertFalse(store.settings.hapticsOn)
        XCTAssertFalse(store.settings.autoStartNext)
        XCTAssertFalse(engine.autoStartNext)
        XCTAssertFalse(store.settings.respectSilentMode)
        XCTAssertEqual(persister.stored, store.settings)
        XCTAssertEqual(persister.saveCount, 4)
    }

    private func makeEngine() -> TimerEngine {
        TimerEngine(durationProvider: FixedDurationProvider(), persister: SettingsTestTimerStateStore())
    }
}

private final class SettingsTestClock: DateProviding {
    var now: Date
    init(now: Date) { self.now = now }
}

private struct FixedDurationProvider: DurationProviding {
    func duration(for phase: Phase) -> Int { 120 }
}

private final class SettingsTestTimerStateStore: TimerStatePersisting {
    private var snapshot: TimerSnapshot?
    var latest: TimerSnapshot? { snapshot }
    init(snapshot: TimerSnapshot? = nil) { self.snapshot = snapshot }
    func load() -> TimerSnapshot? { snapshot }
    func save(_ snapshot: TimerSnapshot) { self.snapshot = snapshot }
}

private final class SettingsSpy: SettingsPersisting {
    var stored: TimerSettings?
    var saveCount = 0
    init(stored: TimerSettings? = nil) { self.stored = stored }
    func load() -> TimerSettings? { stored }
    func save(_ settings: TimerSettings) { stored = settings; saveCount += 1 }
}
