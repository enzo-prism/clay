import SwiftUI
import AppKit

struct SidebarView: View {
    @Binding var selectedTab: ClayTab
    @State private var hoveredTab: ClayTab? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLAY")
                .font(ClayFonts.display(16, weight: .bold))
                .foregroundColor(ClayTheme.accent)
                .padding(.bottom, 12)
            ForEach(ClayTab.allCases) { tab in
                let isHovered = hoveredTab == tab
                let isSelected = selectedTab == tab
                let tint = isSelected ? ClayTheme.accent : (isHovered ? ClayTheme.text : ClayTheme.muted)
                Button {
                    selectedTab = tab
                } label: {
                    HStack {
                        if let image = pixelIcon(for: tab) {
                            PixelIconView(image: image, size: 14, tint: nil)
                        } else {
                            KenneyIconView(path: iconPath(for: tab), size: 14, tint: tint)
                        }
                        Text(tab.title.uppercased())
                            .font(ClayFonts.display(11, weight: .semibold))
                            .foregroundColor(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .allowsTightening(true)
                            .layoutPriority(1)
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 32)
                    .background(
                        RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                            .fill(isSelected ? ClayTheme.panelElevated : (isHovered ? ClayTheme.panelElevated.opacity(0.6) : Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                            .stroke(isSelected ? ClayTheme.accent.opacity(0.6) : (isHovered ? ClayTheme.stroke.opacity(0.8) : Color.clear), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityIdentifier("nav_\(tab.rawValue)")
                .onHover { hovering in
                    hoveredTab = hovering ? tab : nil
                }
            }
            Spacer()
            Text("QUICK ACTIONS")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            VStack(alignment: .leading, spacing: 6) {
                Text("Build • Upgrade • Contracts • Era")
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
            }
        }
        .padding(12)
        .frame(width: 200)
        .background(ClayTheme.panel)
        .overlay(
            Rectangle()
                .fill(ClayTheme.stroke.opacity(0.6))
                .frame(width: 1),
            alignment: .trailing
        )
    }
    
    private func iconPath(for tab: ClayTab) -> String? {
        switch tab {
        case .base:
            return "KenneySelected/Icons/icon_home.png"
        case .projects:
            return "KenneySelected/Icons/icon_wrench.png"
        case .operations:
            return "KenneySelected/Icons/icon_fastforward.png"
        case .partnerships:
            return "KenneySelected/Icons/icon_cart.png"
        case .intel:
            return "KenneySelected/Icons/icon_info.png"
        case .people:
            return "KenneySelected/Icons/icon_user.png"
        case .domains:
            return "KenneySelected/Icons/icon_bars.png"
        case .achievements:
            return "KenneySelected/Icons/icon_power.png"
        case .progress:
            return "KenneySelected/Icons/icon_target.png"
        case .help:
            return "KenneySelected/Icons/icon_info.png"
        case .settings:
            return "KenneySelected/Icons/icon_gear.png"
        }
    }

    private func pixelIcon(for tab: ClayTab) -> NSImage? {
        switch tab {
        case .base:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat00-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 0)
        case .projects:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat01-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 0)
        case .operations:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat01-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 1)
        case .partnerships:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/Reindeer-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 0)
        case .intel:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/Snowman-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 1)
        case .people:
            if let spriteId = PixelAssetCatalog.shared.peoplePackSpriteIds.first {
                if let sprite = PixelAssetCatalog.shared.sprite(for: spriteId),
                   let sheet = sprite.sheet {
                    return PixelAssetCatalog.shared.frameImage(from: sheet, frameIndex: 0)
                }
            }
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat00-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 2)
        case .domains:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat00-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 2)
        case .achievements:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/World/Snowball-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 4, rows: 1, frameCount: 4), frameIndex: 3)
        case .progress:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/World/Snowball-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 4, rows: 1, frameCount: 4), frameIndex: 2)
        case .settings:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/Snowman-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 0)
        case .help:
            return PixelAssetCatalog.shared.frameImage(from: PixelSpriteSheetDefinition(path: "Pixel/Winter-Pixel-Pack/Actors/PersonInCoat00-Standing-Sheet.png", frameWidth: 16, frameHeight: 16, columns: 3, rows: 1, frameCount: 3), frameIndex: 1)
        }
    }
}
