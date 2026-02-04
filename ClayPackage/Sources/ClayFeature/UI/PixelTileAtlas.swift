import AppKit

struct PixelTerrainPalette {
    let grass: [Int]
    let dirt: [Int]
    let water: [Int]
    let structure: [Int]
}

@MainActor
final class PixelTileAtlas {
    struct TileStat {
        let avgR: Double
        let avgG: Double
        let avgB: Double
        let variance: Double
    }

    let tileSize: Int
    let columns: Int
    let rows: Int
    private let tiles: [NSImage]
    private let stats: [TileStat]

    init?(path: String, tileSize: Int = 16) {
        guard let url = PixelAssetCatalog.shared.url(for: path),
              let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        self.tileSize = tileSize
        let columns = max(1, cgImage.width / tileSize)
        let rows = max(1, cgImage.height / tileSize)
        self.columns = columns
        self.rows = rows

        var tiles: [NSImage] = []
        var stats: [TileStat] = []
        tiles.reserveCapacity(columns * rows)
        stats.reserveCapacity(columns * rows)

        for row in 0..<rows {
            for col in 0..<columns {
                let x = col * tileSize
                let y = (rows - 1 - row) * tileSize
                let rect = CGRect(x: x, y: y, width: tileSize, height: tileSize)
                guard let cropped = cgImage.cropping(to: rect) else { continue }
                let tile = NSImage(cgImage: cropped, size: NSSize(width: tileSize, height: tileSize))
                tiles.append(tile)
                stats.append(Self.computeStats(for: cropped))
            }
        }

        self.tiles = tiles
        self.stats = stats
    }

    func tileImage(index: Int) -> NSImage? {
        guard !tiles.isEmpty else { return nil }
        let clamped = max(0, min(index, tiles.count - 1))
        return tiles[clamped]
    }

    func palette() -> PixelTerrainPalette {
        let indices = Array(stats.indices)
        let sortedByGreen = indices.sorted { stats[$0].avgG > stats[$1].avgG }
        let sortedByBlue = indices.sorted { stats[$0].avgB > stats[$1].avgB }
        let sortedByRed = indices.sorted { stats[$0].avgR > stats[$1].avgR }
        let sortedByVariance = indices.sorted { stats[$0].variance > stats[$1].variance }

        let grass = Array(sortedByGreen.prefix(4))
        let water = Array(sortedByBlue.prefix(4))
        let dirt = Array(sortedByRed.prefix(3))
        var structure = sortedByVariance.filter { !grass.contains($0) && !water.contains($0) && !dirt.contains($0) }
        if structure.isEmpty {
            structure = sortedByVariance
        }
        return PixelTerrainPalette(grass: grass, dirt: dirt, water: water, structure: structure)
    }

    private static func computeStats(for cgImage: CGImage) -> TileStat {
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        var sumR: Double = 0
        var sumG: Double = 0
        var sumB: Double = 0
        var sumL: Double = 0
        var sumL2: Double = 0
        let count = Double(max(1, width * height))

        for y in 0..<height {
            for x in 0..<width {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                let r = Double(color.redComponent)
                let g = Double(color.greenComponent)
                let b = Double(color.blueComponent)
                let l = 0.2126 * r + 0.7152 * g + 0.0722 * b
                sumR += r
                sumG += g
                sumB += b
                sumL += l
                sumL2 += l * l
            }
        }

        let avgR = sumR / count
        let avgG = sumG / count
        let avgB = sumB / count
        let avgL = sumL / count
        let variance = max(0, (sumL2 / count) - (avgL * avgL))
        return TileStat(avgR: avgR, avgG: avgG, avgB: avgB, variance: variance)
    }
}
