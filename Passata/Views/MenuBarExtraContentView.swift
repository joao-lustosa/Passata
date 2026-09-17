import AppKit
import SwiftUI

struct MenuBarExtraContentView: View {
    let engine: TimerEngine
    let store: TimerSettingsStore

    @Environment(\.openWindow) private var openWindow

    private var phaseLabel: String {
        engine.phase.displayName
    }

    private var primaryLabel: String {
        switch engine.status {
        case .idle: "Start"
        case .running: "Pause"
        case .paused: "Resume"
        case .complete: ""
        }
    }

    private var timeLabel: String {
        engine.remainingSeconds.asClockString
    }

    private var accent: Color { PassataPalette.accent(for: engine.phase) }

    private var progress: Double {
        let duration = store.duration(for: engine.phase)
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - Double(engine.remainingSeconds) / Double(duration)))
    }

    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
            Text(timeLabel)
                .monospacedDigit()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(phaseLabel)
                    .font(.headline)
                Spacer()
                Text(timeLabel)
                    .font(.title2.monospacedDigit())
            }
            .accessibilityElement(children: .combine)

            SessionDotsView(
                phase: engine.phase,
                sessionIndex: engine.sessionIndex,
                sessionsPerCycle: engine.sessionsPerCycle
            )

            ProgressView(value: progress)
                .tint(accent)

            if engine.status == .paused {
                Text("Paused")
                    .foregroundStyle(.secondary)
            } else if engine.status == .complete {
                Text("Complete")
                    .foregroundStyle(.secondary)
            }

            HStack {
                if engine.status != .complete {
                    Button(primaryLabel, action: engine.togglePrimary)
                }
                Button("Skip", action: engine.onSkip)
                Button("Reset", action: engine.onReset)
                    .disabled(engine.status == .idle)
            }

            Divider()

            Button("Open Passata") {
                openWindow(id: "main")
            }

            Divider()

            Button("Quit Passata") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    var label: some View {
        menuBarLabel
    }
}
