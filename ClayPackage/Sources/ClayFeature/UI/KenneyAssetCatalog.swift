import Foundation
import AppKit

struct KenneyBuildingAsset: Decodable, Hashable {
    let id: String
    let model3d: String
    let scale: Float
    let rotation: Float
    let yOffset: Float
    let cameraDistance: Float
    let tile2d: String?
}

struct KenneyResourceAsset: Decodable, Hashable {
    let id: String
    let icon2d: String
}

struct KenneyAssetManifest: Decodable {
    let buildings: [KenneyBuildingAsset]
    let resources: [KenneyResourceAsset]
    let ui: [String: String]
}

enum KenneyUIKey: String {
    case panel
    case panelElevated
    case buttonPrimary
    case buttonSecondary
    case chip
    case progressTrack
    case progressFill
    case toggleOn
    case toggleOff
    case tabSelected
    case tabUnselected
    case hudBar
}

@MainActor
final class KenneyAssetCatalog {
    static let shared = KenneyAssetCatalog()
    
    private let manifest: KenneyAssetManifest
    private let buildingsById: [String: KenneyBuildingAsset]
    private let resourcesById: [String: KenneyResourceAsset]
    private let uiPaths: [String: String]
    private var imageCache: [String: NSImage] = [:]
    
    private init() {
        if let url = Bundle.module.resourceURL?.appendingPathComponent("kenney_assets.json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(KenneyAssetManifest.self, from: data) {
            manifest = decoded
        } else {
            manifest = KenneyAssetManifest(buildings: [], resources: [], ui: [:])
        }
        buildingsById = Dictionary(uniqueKeysWithValues: manifest.buildings.map { ($0.id, $0) })
        resourcesById = Dictionary(uniqueKeysWithValues: manifest.resources.map { ($0.id, $0) })
        uiPaths = manifest.ui
    }
    
    func buildingAsset(for id: String) -> KenneyBuildingAsset? {
        buildingsById[id]
    }
    
    func resourceIconPath(for id: String) -> String? {
        resourcesById[id]?.icon2d
    }
    
    func uiPath(_ key: KenneyUIKey) -> String? {
        uiPaths[key.rawValue]
    }
    
    func categoryIconPath(for category: String) -> String {
        switch category {
        case "collector": return "KenneySelected/Icons/icon_home.png"
        case "storage": return "KenneySelected/Icons/icon_save.png"
        case "defense": return "KenneySelected/Icons/icon_target.png"
        case "institution": return "KenneySelected/Icons/icon_info.png"
        case "energy": return "KenneySelected/Icons/icon_power.png"
        case "economy": return "KenneySelected/Icons/icon_cart.png"
        case "accelerator": return "KenneySelected/Icons/icon_fastforward.png"
        case "infrastructure": return "KenneySelected/Icons/icon_bars.png"
        case "production": return "KenneySelected/Icons/icon_gear.png"
        case "converter": return "KenneySelected/Icons/icon_wrench.png"
        default: return "KenneySelected/Icons/icon_menu.png"
        }
    }
    
    func url(for path: String) -> URL? {
        if let direct = Bundle.module.resourceURL?.appendingPathComponent(path),
           FileManager.default.fileExists(atPath: direct.path) {
            return direct
        }
        let name = (path as NSString).lastPathComponent
        if let fallback = Bundle.module.url(forResource: name, withExtension: nil) {
            return fallback
        }
        return nil
    }
    
    func image(for path: String, template: Bool = false) -> NSImage? {
        if let cached = imageCache[path] {
            if template { cached.isTemplate = true }
            return cached
        }
        guard let url = url(for: path), let image = NSImage(contentsOf: url) else {
            return nil
        }
        if template {
            image.isTemplate = true
        }
        imageCache[path] = image
        return image
    }
}
