//
//  PassataApp.swift
//  Passata
//
//  Created by João Vitor Leão Lustosa de Souza on 08/09/26.
//

import SwiftUI

@main
struct PassataApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    @State private var store: TimerSettingsStore
    @State private var engine: TimerEngine

    init() {
        let store = TimerSettingsStore(persister: UserDefaultsSettingsStore())
        let feedback = SystemCompletionFeedback()
        #if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
        let liveActivityController = LiveActivityController(publisher: SystemLiveActivityPublisher())
        let phaseCompletionController = PhaseCompletionController(notifier: SystemPhaseCompletionNotifier())
        #endif
        let engine = TimerEngine(
            durationProvider: store,
            dateProvider: SystemDateProvider(),
            persister: UserDefaultsTimerStateStore(),
            autoStartNext: store.settings.autoStartNext,
            onPhaseCompleted: { [store] in
                feedback.play(soundOn: store.settings.soundOn, hapticsOn: store.settings.hapticsOn)
            }
        )
        store.engine = engine

        #if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
        engine.onStateChange = { [weak engine] phase, sessionIndex, render, kind in
            guard let engine else { return }
            liveActivityController.submit(
                phase: phase,
                sessionIndex: sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle,
                render: render,
                kind: kind,
                autoStartNext: engine.autoStartNext
            )
            let upcomingBoundaries = engine.status == .running ? engine.upcomingBoundaries : []
            phaseCompletionController.submit(
                phase: phase,
                sessionIndex: sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle,
                render: render,
                kind: kind,
                autoStartNext: engine.autoStartNext,
                upcomingBoundaries: upcomingBoundaries
            )
            #if os(iOS)
            BackgroundRefreshScheduler.schedule(for: engine)
            #endif
        }

        switch engine.status {
        case .running:
            phaseCompletionController.submit(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle,
                render: engine.currentRenderState,
                kind: .started,
                autoStartNext: engine.autoStartNext,
                upcomingBoundaries: engine.upcomingBoundaries
            )
        case .idle, .paused:
            phaseCompletionController.submit(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle,
                render: engine.currentRenderState,
                kind: .reset,
                autoStartNext: engine.autoStartNext,
                upcomingBoundaries: []
            )
        case .complete where !engine.autoStartNext:
            phaseCompletionController.submit(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle,
                render: engine.currentRenderState,
                kind: .reset,
                autoStartNext: false,
                upcomingBoundaries: []
            )
        case .complete:
            break
        }
        #endif

        #if os(macOS)
        // Keep completion and feedback running even when every window and popover is closed.
        Task { @MainActor in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
                engine.recomputeRemaining()
                engine.checkForCompletion()
            }
        }
        #endif

        #if canImport(ActivityKit) && !os(macOS) && !os(visionOS)
        // Benign race with a queued cold-launch .completed event, if any: every interleaving converges to the correct state, worst case one redundant update() call.
        Task {
            await liveActivityController.reconcileOnLaunch(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle,
                status: engine.status,
                render: engine.currentRenderState
            )
        }
        #endif

        _store = State(initialValue: store)
        _engine = State(initialValue: engine)
    }

    private var timerScreenContent: some View {
        TimerScreen(engine: engine, store: store)
            .modifier(DebugEnvironmentOverrides())
            .frame(minWidth: 420, idealWidth: 500, minHeight: 620, idealHeight: 760)
    }

    var body: some Scene {
        #if os(macOS)
        // Window, not WindowGroup: this app has exactly one meaningful window, and
        // openWindow(id:) against a Window scene brings the existing instance to the
        // front instead of spawning a duplicate the way it does for a WindowGroup id.
        Window("Passata", id: "main") {
            timerScreenContent
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarExtraContentView(engine: engine, store: store)
        } label: {
            MenuBarExtraContentView(engine: engine, store: store).label
        }
        .menuBarExtraStyle(.window)
        #else
        WindowGroup(id: "main") {
            timerScreenContent
                .task {
                    // The scene's backgroundTask modifier registers the launch handler after App.init.
                    // Submit only once the scene content starts, after that registration is in place.
                    BackgroundRefreshScheduler.schedule(for: engine)
                }
        }
        #if os(iOS)
        .backgroundTask(.appRefresh(BackgroundRefreshScheduler.identifier)) {
            await MainActor.run { BackgroundRefreshScheduler.reconcile(engine) }
        }
        #endif
        #endif
    }
}
