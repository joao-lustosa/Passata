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
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: SystemDateProvider(),
            persister: UserDefaultsTimerStateStore()
        )
        store.engine = engine
        engine.autoStartNext = store.settings.autoStartNext

        let feedback = SystemCompletionFeedback()
        engine.onPhaseCompleted = { [store] in
            feedback.play(soundOn: store.settings.soundOn, hapticsOn: store.settings.hapticsOn)
        }

        _store = State(initialValue: store)
        _engine = State(initialValue: engine)
    }

    var body: some Scene {
        WindowGroup {
            TimerScreen(engine: engine, store: store)
        }
    }
}
