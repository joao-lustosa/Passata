import SwiftUI

struct DurationStepperRowView: View {
    let label: String
    let valueLabel: String
    let entryValue: String
    let entryPrompt: String
    let canDecrease: Bool
    let canIncrease: Bool
    let onMinus: () -> Void
    let onPlus: () -> Void
    let onValueSubmit: (String) -> Bool

    @State private var isShowingValueEntry = false
    @State private var typedValue = ""
    @State private var validationError: String?

    @ScaledMetric(relativeTo: .body) private var labelFontSize = 16.0
    @ScaledMetric(relativeTo: .body) private var valueFontSize = 15.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundStyle(Color("PassataInk"))

                Spacer(minLength: 0)

                HStack(spacing: 2) {
                    stepperButton(symbol: "minus", enabled: canDecrease, action: onMinus)

                    Button {
                        typedValue = entryValue
                        validationError = nil
                        isShowingValueEntry = true
                    } label: {
                        Text(valueLabel)
                            .font(.system(size: valueFontSize))
                            .monospacedDigit()
                            .foregroundStyle(Color("PassataInk2"))
                            .frame(minWidth: 56)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Tap to enter a custom value")

                    stepperButton(symbol: "plus", enabled: canIncrease, action: onPlus)
                }
                .padding(.trailing, -8)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)

            if let validationError {
                Text(validationError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .accessibilityLabel("Invalid \(label) value. \(validationError)")
            }
        }
        .alert("Set \(label)", isPresented: $isShowingValueEntry) {
            TextField("Value", text: $typedValue)
                #if os(iOS)
                .keyboardType(.numbersAndPunctuation)
                #endif
            Button("Apply") {
                if !onValueSubmit(typedValue) {
                    validationError = "Enter a valid value within the allowed range."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(entryPrompt)
        }
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
