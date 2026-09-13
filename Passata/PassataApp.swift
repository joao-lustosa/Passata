//
//  PassataApp.swift
//  Passata
//
//  Created by João Vitor Leão Lustosa de Souza on 08/09/26.
//

import SwiftUI

@main
struct PassataApp: App {
    @State private var store: TimerSettingsStore
    @State private var engine: TimerEngine

    init() {
        let store = TimerSettingsStore(persister: UserDefaultsSettingsStore())
        let feedback = SystemCompletionFeedback()
        #if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
        let liveActivityController = LiveActivityController(publisher: SystemLiveActivityPublisher())
        let phaseCompletionController = PhaseCompletionController(notifier: SystemPhaseCompletionNotifier())
        let onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TimerEngine.TransitionKind) -> Void)? = { phase, sessionIndex, render, kind in
            liveActivityController.submit(
                phase: phase,
                sessionIndex: sessionIndex,
                render: render,
                kind: kind
            )
            phaseCompletionController.submit(
                phase: phase,
                sessionIndex: sessionIndex,
                render: render,
                kind: kind
            )
        }
        #else
        let onStateChange: ((_ phase: Phase, _ sessionIndex: Int, _ render: RenderState, _ kind: TimerEngine.TransitionKind) -> Void)? = nil
        #endif
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: SystemDateProvider(),
            persister: UserDefaultsTimerStateStore(),
            autoStartNext: store.settings.autoStartNext,
            onPhaseCompleted: { [store] in
                feedback.play(soundOn: store.settings.soundOn, hapticsOn: store.settings.hapticsOn)
            },
            onStateChange: onStateChange
        )
        store.engine = engine

        #if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
        // Benign race with a queued cold-launch .completed event, if any: every interleaving converges to the correct state, worst case one redundant update() call.
        Task {
            await liveActivityController.reconcileOnLaunch(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                status: engine.status,
                render: engine.currentRenderState
            )
        }
        #endif

        _store = State(initialValue: store)
        _engine = State(initialValue: engine)
    }

    var body: some Scene {
        WindowGroup {
            TimerScreen(engine: engine, store: store)
                .modifier(DebugEnvironmentOverrides())
                .frame(minWidth: 420, idealWidth: 500, minHeight: 620, idealHeight: 760)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
