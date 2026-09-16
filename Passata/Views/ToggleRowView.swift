import SwiftUI

struct ToggleRowView: View {
    let label: String
    @Binding var isOn: Bool

    @ScaledMetric(relativeTo: .body) private var labelFontSize = 16.0

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(label)
                .font(.system(size: labelFontSize, weight: .medium))
                .foregroundStyle(Color("PassataInk"))
        }
        .toggleStyle(.switch)
        .tint(Color("PassataFocus"))
        .padding(.horizontal, 16)
        .frame(minHeight: 46)
    }
}
