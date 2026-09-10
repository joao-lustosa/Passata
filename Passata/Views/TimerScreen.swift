import SwiftUI

struct TimerScreen: View {
    let engine: TimerEngine
    let store: TimerSettingsStore

    @State private var settingsOpen = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                Color("PassataBackground")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    TopBarView(engine: engine) {
                        settingsOpen = true
                    }

                    Spacer()

                    ProgressRingView(engine: engine, durationProvider: store)

                    Spacer()

                    ControlsBarView(engine: engine)
                }

                if engine.status == .complete {
                    CompletionOverlayView(engine: engine)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(.default, value: engine.status)
            .onChange(of: context.date) { _, _ in
                engine.recomputeRemaining()
                engine.checkForCompletion()
            }
        }
        .onAppear {
            if scenePhase == .active {
                engine.checkForCompletion()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                engine.checkForCompletion()
            }
        }
        .sheet(isPresented: $settingsOpen) {
            SettingsSheetView(store: store) {
                settingsOpen = false
            }
            .presentationDetents([.fraction(0.72)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(32)
            .presentationBackground {
                if reduceTransparency {
                    PassataPalette.sheetRTBackground()
                } else {
                    let sheetGlassTint = colorScheme == .dark
                        ? Color(red: 28 / 255, green: 28 / 255, blue: 32 / 255).opacity(0.78)
                        : Color(red: 250 / 255, green: 248 / 255, blue: 246 / 255).opacity(0.94)
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular.tint(sheetGlassTint), in: .rect(cornerRadius: 32))
                }
            }
        }
    }
}
