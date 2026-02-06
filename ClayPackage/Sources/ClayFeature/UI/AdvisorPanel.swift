import SwiftUI

struct AdvisorPanel: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
                .claySingleLine(minScale: 0.8)
            Text(message)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
                .clayTwoLines(minScale: 0.9)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}
