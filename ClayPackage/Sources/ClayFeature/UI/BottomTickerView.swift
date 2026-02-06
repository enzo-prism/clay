import SwiftUI

struct BottomTickerView: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        HStack(spacing: 12) {
            Text("RECENT EVENTS - TAP TO INTEL")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
                .claySingleLine(minScale: 0.75)

            if engine.state.events.isEmpty {
                Text("No recent events.")
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.75)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(engine.state.events.prefix(5)) { event in
                            TickerPill(title: event.title, category: event.category)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.intel)
        }
        .background(ClayTheme.panel)
        .overlay(
            Rectangle()
                .fill(ClayTheme.stroke.opacity(0.6))
                .frame(height: 1),
            alignment: .top
        )
    }
}

private struct TickerPill: View {
    let title: String
    let category: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appear = false

    var body: some View {
        HStack(spacing: 6) {
            if let iconDef = PixelAssetCatalog.shared.eventIcon(for: category),
               let image = PixelAssetCatalog.shared.iconImage(for: iconDef) {
                PixelIconView(image: image, size: 12, tint: nil)
            }
            Text(title)
                .font(ClayFonts.data(10))
                .claySingleLine(minScale: 0.75)
                .frame(maxWidth: 220, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 6)
        .onAppear {
            if reduceMotion {
                appear = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    appear = true
                }
            }
        }
    }
}
