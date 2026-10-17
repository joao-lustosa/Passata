import SwiftUI

struct PresetRowView: View {
    let label: String
    let valueLabel: String
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var labelFontSize = 16.0
    @ScaledMetric(relativeTo: .body) private var valueFontSize = 15.5

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundStyle(Color("PassataInk"))

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text(valueLabel)
                        .font(.system(size: valueFontSize))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color("PassataInk2"))
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 46)
        }
        .buttonStyle(.plain)
        .passataMacHoverFeedback()
    }
}
