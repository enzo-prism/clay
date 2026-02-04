import SwiftUI
import AppKit

struct BuildingIconView: View {
    let buildingId: String
    let category: String
    var size: CGFloat = 20
    var tint: Color = ClayTheme.text
    
    var body: some View {
        if let symbol = categorySymbol(for: category), symbolAvailable(symbol) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(tint)
        } else {
            let asset = KenneyAssetCatalog.shared.buildingAsset(for: buildingId)
            let path = asset?.tile2d ?? KenneyAssetCatalog.shared.categoryIconPath(for: category)
            if KenneyAssetCatalog.shared.image(for: path) != nil {
                KenneyIconView(path: path, size: size, tint: tint)
            } else {
                Text(BuildingIconCatalog.icon(for: buildingId, category: category))
                    .font(.system(size: size))
            }
        }
    }

    private func categorySymbol(for category: String) -> String? {
        switch category {
        case "collector", "production", "energy", "economy", "converter":
            return "chart.line.uptrend.xyaxis"
        case "defense":
            return "shield.fill"
        default:
            return nil
        }
    }

    private func symbolAvailable(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}

struct ResourceIconView: View {
    let resourceId: String
    var size: CGFloat = 16
    var tint: Color = ClayTheme.text
    
    var body: some View {
        if let pixelDef = PixelAssetCatalog.shared.resourceIcon(for: resourceId),
           let image = PixelAssetCatalog.shared.iconImage(for: pixelDef) {
            PixelIconView(image: image, size: size, tint: tint)
        } else if let path = KenneyAssetCatalog.shared.resourceIconPath(for: resourceId),
                  KenneyAssetCatalog.shared.image(for: path) != nil {
            KenneyIconView(path: path, size: size, tint: tint)
        } else {
            Text(resourceId.prefix(1).uppercased())
                .font(ClayFonts.display(size, weight: .semibold))
        }
    }
}
