import SwiftUI
import AppKit

struct DomainsView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Domains", subtitle: "Develop your playstyle and unlock tier bonuses.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(engine.content.pack.domains) { domain in
                        DomainCard(domain: domain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }
}

struct DomainCard: View {
    @EnvironmentObject private var engine: GameEngine
    let domain: DomainDefinition

    var body: some View {
        let points = engine.state.domainState.pointsByDomain[domain.id, default: 0]
        let unlockedTier = engine.state.domainState.unlockedTiersByDomain[domain.id, default: 0]
        let nextTier = domain.tiers.sorted { $0.tier < $1.tier }.first { $0.tier > unlockedTier }
        let progressValue: Double = {
            guard let nextTier else { return 1.0 }
            return min(1.0, Double(points) / Double(max(1, nextTier.requiredPoints)))
        }()
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let image = domainIconImage() {
                    PixelIconView(image: image, size: 18, tint: nil)
                } else {
                    KenneyIconView(path: domain.iconPath, size: 16, tint: ClayTheme.accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(domain.name)
                        .font(ClayFonts.display(12, weight: .semibold))
                    Text(domain.description)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                }
                Spacer()
                Text("Tier \(unlockedTier)")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.good)
            }
            SimpleProgressBar(value: progressValue)
            if let nextTier {
                Text("Next: \(points)/\(nextTier.requiredPoints) points")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                DomainTierEffectRow(tier: nextTier, domain: domain)
            } else {
                Text("Max tier achieved")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.good)
            }
            if unlockedTier > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Bonuses")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.accent)
                    ForEach(domain.tiers.filter { $0.tier <= unlockedTier }, id: \.tier) { tier in
                        ForEach(tier.effects.indices, id: \.self) { index in
                            let effect = tier.effects[index]
                            Text("• \(EffectDescriptor.describe(effect, content: engine.content))")
                                .font(ClayFonts.data(9))
                                .foregroundColor(ClayTheme.muted)
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
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }

    private func domainIconImage() -> NSImage? {
        let sheet: PixelSpriteSheetDefinition
        let index: Int
        switch domain.id {
        case "industry":
            sheet = PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat00-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3)
            index = 0
        case "science":
            sheet = PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat01-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3)
            index = 1
        case "diplomacy":
            sheet = PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/Reindeer-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3)
            index = 0
        case "infrastructure":
            sheet = PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/Snowman-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3)
            index = 0
        default:
            return nil
        }
        return PixelAssetCatalog.shared.frameImage(from: sheet, frameIndex: index)
    }
}

struct DomainTierEffectRow: View {
    @EnvironmentObject private var engine: GameEngine
    let tier: DomainTierDefinition
    let domain: DomainDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tier \(tier.tier) rewards")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            ForEach(tier.effects.indices, id: \.self) { index in
                let effect = tier.effects[index]
                Text("• \(EffectDescriptor.describe(effect, content: engine.content))")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
            }
        }
    }
}
