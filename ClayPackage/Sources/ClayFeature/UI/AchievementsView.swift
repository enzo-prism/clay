import SwiftUI
import AppKit

struct AchievementsView: View {
    @EnvironmentObject private var engine: GameEngine
    @State private var filter: AchievementFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Achievements", subtitle: "Earn long-term goals for permanent bonuses.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SegmentedControl(segments: AchievementFilter.allCases, selection: $filter, activeTint: ClayTheme.accentWarm) { segment, isSelected in
                        Text(segment.label.uppercased())
                            .font(ClayFonts.display(8, weight: .semibold))
                            .foregroundColor(isSelected ? ClayTheme.accentText : ClayTheme.muted)
                            .claySingleLine(minScale: 0.7)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                    }
                    ForEach(filteredAchievements()) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }

    private func filteredAchievements() -> [AchievementDefinition] {
        switch filter {
        case .all:
            return engine.content.pack.achievements
        case .unlocked:
            return engine.content.pack.achievements.filter { engine.state.achievementsUnlocked.contains($0.id) }
        case .locked:
            return engine.content.pack.achievements.filter { !engine.state.achievementsUnlocked.contains($0.id) }
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
                    .claySingleLine(minScale: 0.8)
                Spacer()
                Text(unlocked ? "UNLOCKED" : "LOCKED")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(unlocked ? ClayTheme.good : ClayTheme.muted)
                    .claySingleLine(minScale: 0.75)
            }
            Text(achievement.description)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
            if !achievement.effects.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rewards")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.accent)
                        .claySingleLine(minScale: 0.85)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(achievement.effects.indices, id: \.self) { index in
                                let effect = achievement.effects[index]
                                RewardTag(text: EffectDescriptor.describe(effect, content: engine.content))
                            }
                        }
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

private enum AchievementFilter: String, CaseIterable, Hashable {
    case all
    case unlocked
    case locked

    var label: String {
        switch self {
        case .all: return "All"
        case .unlocked: return "Unlocked"
        case .locked: return "Locked"
        }
    }
}

private struct RewardTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(ClayFonts.data(9))
            .foregroundColor(ClayTheme.muted)
            .claySingleLine(minScale: 0.7)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ClayTheme.panelElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
            )
    }
}
