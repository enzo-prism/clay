import SwiftUI

struct BackgroundView: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [ClayTheme.bg, ClayTheme.bg2], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color.white.opacity(0.06), .clear], center: .top, startRadius: 40, endRadius: 400)
                    .blendMode(.screen)
            }
            .ignoresSafeArea()
        }
    }
}
