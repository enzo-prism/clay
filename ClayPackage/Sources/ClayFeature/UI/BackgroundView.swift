import SwiftUI

struct BackgroundView: View {
    @Environment(\.eraTheme) private var eraTheme

    var body: some View {
        ZStack {
            LinearGradient(colors: [eraTheme.backgroundTop, eraTheme.backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [eraTheme.accent.opacity(0.08), .clear], center: .top, startRadius: 40, endRadius: 420)
                .blendMode(.screen)
            NoiseOverlay()
        }
        .ignoresSafeArea()
    }
}

private struct NoiseOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 7
            for x in stride(from: 0, to: size.width, by: step) {
                for y in stride(from: 0, to: size.height, by: step) {
                    if (Int(x + y) % 3) == 0 {
                        let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                        context.fill(Path(rect), with: .color(Color.white.opacity(0.04)))
                    }
                }
            }
        }
        .blendMode(.softLight)
        .opacity(0.5)
    }
}
