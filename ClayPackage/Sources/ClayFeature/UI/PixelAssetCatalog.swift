import Foundation
import AppKit

struct PixelSpriteSheetDefinition: Codable {
    var path: String
    var frameWidth: Int
    var frameHeight: Int
    var columns: Int?
    var rows: Int?
    var frameCount: Int?
}

struct PixelSpriteDefinition: Codable {
    var frames: [String]
    var fps: Double
    var scale: Double?
    var sheet: PixelSpriteSheetDefinition?
    var idleSheet: PixelSpriteSheetDefinition?
}

struct PixelIconDefinition: Codable {
    var path: String?
    var sheet: PixelSpriteSheetDefinition?
    var frameIndex: Int?

    init(path: String) {
        self.path = path
        self.sheet = nil
        self.frameIndex = nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.path = string
            self.sheet = nil
            self.frameIndex = nil
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.path = try keyed.decodeIfPresent(String.self, forKey: .path)
        self.sheet = try keyed.decodeIfPresent(PixelSpriteSheetDefinition.self, forKey: .sheet)
        self.frameIndex = try keyed.decodeIfPresent(Int.self, forKey: .frameIndex)
    }

    enum CodingKeys: String, CodingKey {
        case path
        case sheet
        case frameIndex
    }
}

struct PixelAssetPack: Codable {
    var resourceIcons: [String: PixelIconDefinition]
    var eventIcons: [String: PixelIconDefinition]
    var actionSprites: [String: PixelSpriteDefinition]
    var characterSprites: [String: PixelSpriteDefinition]

    static let empty = PixelAssetPack(resourceIcons: [:], eventIcons: [:], actionSprites: [:], characterSprites: [:])
}

@MainActor
final class PixelAssetCatalog {
    static let shared = PixelAssetCatalog()

    private(set) var pack: PixelAssetPack
    private(set) var peoplePackSpriteIds: [String] = []
    private(set) var peoplePackName: String? = nil
    private(set) var peoplePackCredits: String? = nil
    private var colorKeyCache: [String: NSImage] = [:]
    private let colorKey = NSColor(calibratedRed: 101.0 / 255.0, green: 1.0, blue: 0.0, alpha: 1.0)

    private init() {
        var basePack: PixelAssetPack = .empty
        if let url = Bundle.module.url(forResource: "pixel_assets", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(PixelAssetPack.self, from: data) {
            basePack = decoded
        }
        pack = basePack
        peoplePackSpriteIds = []
        let peopleResult = Self.loadPeoplePackSprites()
        if !peopleResult.sprites.isEmpty {
            var merged = basePack
            for (id, sprite) in peopleResult.sprites {
                merged.characterSprites[id] = sprite
            }
            peoplePackSpriteIds = peopleResult.sprites.keys.sorted()
            peoplePackName = peopleResult.name
            peoplePackCredits = peopleResult.credits
            pack = merged
        }
    }

    func image(for path: String?) -> NSImage? {
        guard let path, let url = url(for: path) else { return nil }
        if let cached = colorKeyCache[path] {
            return cached
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        let processed = applyColorKey(image)
        colorKeyCache[path] = processed
        return processed
    }

    func url(for path: String) -> URL? {
        if let direct = Bundle.module.url(forResource: path, withExtension: nil) {
            return direct
        }
        let filename = (path as NSString).lastPathComponent
        if let flat = Bundle.module.url(forResource: filename, withExtension: nil) {
            return flat
        }
        let name = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        if !name.isEmpty {
            return Bundle.module.url(forResource: name, withExtension: ext.isEmpty ? nil : ext)
        }
        return nil
    }

    func resourceIcon(for resourceId: String) -> PixelIconDefinition? {
        pack.resourceIcons[resourceId]
    }

    func eventIcon(for category: String) -> PixelIconDefinition? {
        pack.eventIcons[category]
    }

    func sprite(for id: String) -> PixelSpriteDefinition? {
        pack.actionSprites[id] ?? pack.characterSprites[id]
    }

    private static func loadPeoplePackSprites() -> (sprites: [String: PixelSpriteDefinition], name: String?, credits: String?) {
        if let lpc = loadPack(folder: "Pixel/LPCPack", defaultFrame: 64, packName: "LPC") {
            return lpc
        }
        if let pack = loadPack(folder: "Pixel/PeoplePack", defaultFrame: 16, packName: "PeoplePack") {
            return pack
        }
        return ([:], nil, nil)
    }

    private static func loadPack(folder: String, defaultFrame: Int, packName: String) -> (sprites: [String: PixelSpriteDefinition], name: String?, credits: String?)? {
        guard let resourceRoot = Bundle.module.resourceURL?.appendingPathComponent(folder) else {
            return nil
        }
        guard FileManager.default.fileExists(atPath: resourceRoot.path),
              let enumerator = FileManager.default.enumerator(at: resourceRoot, includingPropertiesForKeys: nil) else {
            return nil
        }
        var results: [String: PixelSpriteDefinition] = [:]
        for case let url as URL in enumerator {
            guard url.pathExtension.lowercased() == "png" else { continue }
            let filename = url.lastPathComponent
            let rawId = url.deletingPathExtension().lastPathComponent
            let frameSize = inferFrameSize(url: url, fallback: defaultFrame)
            let path = "\(folder)/\(filename)"
            if frameSize <= 0 { continue }
            let columns = inferColumns(url: url, frameSize: frameSize)
            let rows = inferRows(url: url, frameSize: frameSize)
            for row in 0..<rows {
                let variantId = normalizeSpriteId("\(rawId)_row\(row)")
                results[variantId] = PixelSpriteDefinition(
                    frames: [],
                    fps: 8,
                    scale: 1.0,
                    sheet: PixelSpriteSheetDefinition(path: path, frameWidth: frameSize, frameHeight: frameSize, columns: columns, rows: rows, frameCount: columns)
                )
            }
        }
        if !results.isEmpty {
            let credits = loadCredits(folder: folder)
            return (results, packName, credits)
        }
        return nil
    }

    private static func inferFrameSize(url: URL, fallback: Int) -> Int {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return fallback }
        let width = cgImage.width
        let height = cgImage.height
        let candidates = [64, 48, 32, 24, 16]
        for size in candidates {
            if width % size == 0 && height % size == 0 {
                return size
            }
        }
        return fallback
    }

    private static func inferColumns(url: URL, frameSize: Int) -> Int {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 1 }
        return max(1, cgImage.width / frameSize)
    }

    private static func inferRows(url: URL, frameSize: Int) -> Int {
        guard let image = NSImage(contentsOf: url),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 1 }
        return max(1, cgImage.height / frameSize)
    }

    private static func loadCredits(folder: String) -> String? {
        guard let resourceRoot = Bundle.module.resourceURL?.appendingPathComponent(folder) else { return nil }
        let candidates = ["CREDITS.txt", "credits.txt", "CREDITS.csv", "credits.csv"]
        for name in candidates {
            let url = resourceRoot.appendingPathComponent(name)
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8),
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }

    private static func normalizeSpriteId(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
    }

    func iconImage(for definition: PixelIconDefinition?) -> NSImage? {
        guard let definition else { return nil }
        if let path = definition.path, let image = image(for: path) {
            return image
        }
        if let sheet = definition.sheet {
            let index = definition.frameIndex ?? 0
            return frameImage(from: sheet, frameIndex: index)
        }
        return nil
    }

    func frameCount(for sheet: PixelSpriteSheetDefinition) -> Int {
        guard let image = image(for: sheet.path),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 1 }
        let columns = sheet.columns ?? max(1, cgImage.width / sheet.frameWidth)
        let rows = sheet.rows ?? max(1, cgImage.height / sheet.frameHeight)
        return sheet.frameCount ?? (columns * rows)
    }

    func frameImage(from sheet: PixelSpriteSheetDefinition, frameIndex: Int) -> NSImage? {
        guard let image = image(for: sheet.path),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let columns = sheet.columns ?? max(1, cgImage.width / sheet.frameWidth)
        let rows = sheet.rows ?? max(1, cgImage.height / sheet.frameHeight)
        let count = sheet.frameCount ?? (columns * rows)
        let index = max(0, min(frameIndex, count - 1))
        let col = index % columns
        let row = index / columns
        let x = col * sheet.frameWidth
        let y = (rows - 1 - row) * sheet.frameHeight
        let rect = CGRect(x: x, y: y, width: sheet.frameWidth, height: sheet.frameHeight)
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        let size = NSSize(width: sheet.frameWidth, height: sheet.frameHeight)
        let frame = NSImage(cgImage: cropped, size: size)
        return applyColorKey(frame)
    }

    private func applyColorKey(_ image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let width = rep.pixelsWide
        let height = rep.pixelsHigh
        let key = colorKey
        for y in 0..<height {
            for x in 0..<width {
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                if isColorKey(color, key: key) {
                    let cleared = NSColor(calibratedRed: color.redComponent, green: color.greenComponent, blue: color.blueComponent, alpha: 0.0)
                    rep.setColor(cleared, atX: x, y: y)
                }
            }
        }
        let result = NSImage(size: image.size)
        result.addRepresentation(rep)
        return result
    }

    private func isColorKey(_ color: NSColor, key: NSColor) -> Bool {
        let r = color.redComponent
        let g = color.greenComponent
        let b = color.blueComponent
        // Allow a little tolerance around the bright green key.
        return g > 0.9 && r < 0.5 && b < 0.2
    }
}
