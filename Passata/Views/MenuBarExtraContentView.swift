import AppKit
import SwiftUI

struct MenuBarExtraContentView: View {
    let engine: TimerEngine
    let store: TimerSettingsStore

    @Environment(\.openWindow) private var openWindow

    private var phaseLabel: String {
        switch engine.phase {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
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
        String(format: "%02d:%02d", engine.remainingSeconds / 60, engine.remainingSeconds % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(phaseLabel)
                    .font(.headline)
                Spacer()
                Text(timeLabel)
                    .font(.title2.monospacedDigit())
            }
            .accessibilityElement(children: .combine)

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
}
