import SwiftUI
import AppKit

struct AchievementsView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Achievements", subtitle: "Earn long-term goals for permanent bonuses.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(engine.content.pack.achievements) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }
}

struct AchievementCard: View {
    @EnvironmentObject private var engine: GameEngine
    let achievement: AchievementDefinition

    var body: some View {
        let unlocked = engine.state.achievementsUnlocked.contains(achievement.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let image = achievementIcon(unlocked: unlocked) {
                    PixelIconView(image: image, size: 16, tint: nil)
                }
                Text(achievement.name)
                    .font(ClayFonts.display(12, weight: .semibold))
                Spacer()
                Text(unlocked ? "UNLOCKED" : "LOCKED")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(unlocked ? ClayTheme.good : ClayTheme.muted)
            }
            Text(achievement.description)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
            if !achievement.effects.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rewards")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.accent)
                    ForEach(achievement.effects.indices, id: \.self) { index in
                        let effect = achievement.effects[index]
                        Text("• \(EffectDescriptor.describe(effect, content: engine.content))")
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.muted)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(unlocked ? ClayTheme.good.opacity(0.6) : ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }

    private func achievementIcon(unlocked: Bool) -> NSImage? {
        let sheet = PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/World/Snowball-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 4, rows: 1, frameCount: 4)
        let index = unlocked ? 3 : 1
        return PixelAssetCatalog.shared.frameImage(from: sheet, frameIndex: index)
    }
}
