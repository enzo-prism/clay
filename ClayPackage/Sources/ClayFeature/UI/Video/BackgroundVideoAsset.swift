import Foundation

enum BackgroundVideoAsset {
    static func assetName(forEraId eraId: String) -> String {
        switch eraId {
        case "stone", "agrarian":
            return "bg_stone"
        case "metallurgy", "industrial":
            return "bg_industrial"
        case "planetary", "stellar", "galactic":
            return "bg_stellar"
        default:
            return "bg_stone"
        }
    }

    static func url(forEraId eraId: String) -> URL? {
        Bundle.module.url(forResource: assetName(forEraId: eraId), withExtension: "mp4", subdirectory: "Video/Backgrounds")
    }
}

