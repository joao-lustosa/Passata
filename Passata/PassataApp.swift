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
        let liveActivityController = LiveActivityController()
        let phaseCompletionController = PhaseCompletionController()
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: SystemDateProvider(),
            persister: UserDefaultsTimerStateStore(),
            autoStartNext: store.settings.autoStartNext,
            onPhaseCompleted: { [store] in
                feedback.play(soundOn: store.settings.soundOn, hapticsOn: store.settings.hapticsOn)
            },
            onStateChange: { phase, sessionIndex, render, kind in
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
        )
        store.engine = engine

        Task {
            await liveActivityController.reconcileOnLaunch(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                status: engine.status,
                render: engine.currentRenderState
            )
        }

        _store = State(initialValue: store)
        _engine = State(initialValue: engine)
    }

    var body: some Scene {
        WindowGroup {
            TimerScreen(engine: engine, store: store)
                .modifier(DebugEnvironmentOverrides())
        }
    }
}
