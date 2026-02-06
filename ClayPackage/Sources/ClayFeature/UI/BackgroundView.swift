import SwiftUI

struct BackgroundView: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.eraTheme) private var eraTheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let url = BackgroundVideoAsset.url(forEraId: engine.state.eraId)
        let canPlay = engine.state.settings.animatedBackgroundsEnabled && !reduceMotion && scenePhase == .active

        ZStack {
            LinearGradient(
                colors: [eraTheme.backgroundTop, eraTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if let url, canPlay {
                LoopingVideoView(url: url, isPlaying: canPlay)
                    .id(url)
                    .transition(.opacity)
                    .opacity(0.28)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // Keep text readable even if the clip comes out brighter than expected.
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .blendMode(.multiply)
            .allowsHitTesting(false)

            RadialGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.86)]),
                center: .center,
                startRadius: 120,
                endRadius: 900
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.35), value: canPlay)
        .animation(.easeInOut(duration: 0.35), value: url)
        .allowsHitTesting(false)
    }
}
