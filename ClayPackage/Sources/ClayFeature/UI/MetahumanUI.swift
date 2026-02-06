import SwiftUI

struct MetahumanAffinityMeter: View {
    let affinity: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("Affinity")
                .font(ClayFonts.data(8, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            ForEach(0..<5) { index in
                let level = index - 2
                Circle()
                    .fill(level <= affinity ? accent : ClayTheme.panel)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
            }
        }
    }
}

struct MetahumanPowerTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(ClayFonts.display(8, weight: .semibold))
            .foregroundColor(tint)
            .claySingleLine(minScale: 0.6)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
    }
}
