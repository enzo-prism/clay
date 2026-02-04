import AppKit

@MainActor
final class BuildingDetailImageCatalog {
    static let shared = BuildingDetailImageCatalog()

    private let mapping: [String: String] = [
        "foraging_hut": "BuildingDetails/foraging_hut.png",
        "quarry": "BuildingDetails/quarry.png",
        "granary": "BuildingDetails/granary.png",
        "stockpile": "BuildingDetails/stockpile.png",
        "palisade": "BuildingDetails/palisade.png",
        "lookout": "BuildingDetails/lookout.png",
        "farm": "BuildingDetails/farm.png",
        "irrigation_channel": "BuildingDetails/irrigation_channel.png",
        "silo": "BuildingDetails/silo.png",
        "trade_post": "BuildingDetails/trade_post.png",
        "partnership_office": "BuildingDetails/partnership_office.png",
        "watchtower": "BuildingDetails/watchtower.png",
        "smelter": "BuildingDetails/smelter.png",
        "academy": "BuildingDetails/academy.png",
        "foundry": "BuildingDetails/foundry.png",
        "depot": "BuildingDetails/depot.png",
        "embassy": "BuildingDetails/embassy.png",
        "fortified_wall": "BuildingDetails/fortified_wall.png",
        "workshop": "BuildingDetails/workshop.png",
        "generator": "BuildingDetails/generator.png"
    ]

    private init() {}

    func image(for buildingId: String) -> NSImage? {
        guard let path = mapping[buildingId] else { return nil }
        return PixelAssetCatalog.shared.image(for: path)
    }
}

@MainActor
final class PixelBuildingDetailFallback {
    static let shared = PixelBuildingDetailFallback()

    private let atlas: PixelTileAtlas?
    private let palette: PixelTerrainPalette?

    private init() {
        if let atlas = PixelTileAtlas(path: "Pixel/PunyWorld/punyworld-overworld-tileset.png", tileSize: 16) {
            self.atlas = atlas
            self.palette = atlas.palette()
        } else if let atlas = PixelTileAtlas(path: "Pixel/Winter-Pixel-Pack/World/Winter-Tileset.png", tileSize: 16) {
            self.atlas = atlas
            self.palette = atlas.palette()
        } else {
            self.atlas = nil
            self.palette = nil
        }
    }

    func image(for buildingId: String) -> NSImage? {
        guard let atlas, let palette, !palette.structure.isEmpty else { return nil }
        let index = abs(buildingId.hashValue) % palette.structure.count
        return atlas.tileImage(index: palette.structure[index])
    }
}
