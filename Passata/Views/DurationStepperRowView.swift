import SwiftUI

struct DurationStepperRowView: View {
    let label: String
    let valueLabel: String
    let canDecrease: Bool
    let canIncrease: Bool
    let onMinus: () -> Void
    let onPlus: () -> Void

    @ScaledMetric(relativeTo: .body) private var labelFontSize = 16.0
    @ScaledMetric(relativeTo: .body) private var valueFontSize = 15.0

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: labelFontSize, weight: .medium))
                .foregroundStyle(Color("PassataInk"))

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                stepperButton(symbol: "minus", enabled: canDecrease, action: onMinus)

                Text(valueLabel)
                    .font(.system(size: valueFontSize))
                    .monospacedDigit()
                    .foregroundStyle(Color("PassataInk2"))
                    .frame(minWidth: 56)

                stepperButton(symbol: "plus", enabled: canIncrease, action: onPlus)
            }
            .padding(.trailing, -8)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
    }

    private func stepperButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("PassataInk"))
                .frame(width: 44, height: 44)
                .background {
                    Circle()
                        .fill(Color("PassataTrack"))
                        .padding(8)
                }
        }
        .buttonStyle(.plain)
        .passataMacHoverFeedback()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(symbol == "minus" ? "Decrease \(label)" : "Increase \(label)")
    }
}
