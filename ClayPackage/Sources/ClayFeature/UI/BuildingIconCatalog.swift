import Foundation

enum BuildingIconCatalog {
    private static let byId: [String: String] = [
        "foraging_hut": "🛖",
        "quarry": "⛏️",
        "granary": "🌾",
        "stockpile": "📦",
        "palisade": "🛡️",
        "lookout": "👁️",
        "farm": "🌿",
        "irrigation_channel": "💧",
        "silo": "🏺",
        "trade_post": "🏪",
        "partnership_office": "🤝",
        "watchtower": "🗼",
        "smelter": "🔥",
        "academy": "📚",
        "foundry": "🏭",
        "depot": "🧱",
        "embassy": "🕊️",
        "fortified_wall": "🧱",
        "workshop": "🛠️",
        "generator": "⚡️",
        "grid_node": "🔌",
        "market_exchange": "💱",
        "vault": "🔒",
        "security_center": "🛡️",
        "logistics_hub": "🚚",
        "automation_foundry": "🤖",
        "solar_array_field": "☀️",
        "planetary_battery": "🔋",
        "planetary_relay": "📡",
        "orbital_platform": "🛰️",
        "shield_grid": "🛡️",
        "control_node": "🧠",
        "stellar_collector_node": "🌟",
        "relay_nexus": "🌀",
        "galactic_archive": "🗄️",
        "stellar_vault": "🧰",
        "shield_protocol_array": "🛡️",
        "relay_fabricator": "🧪",
        "galactic_relay_node": "🌌"
    ]
    
    static func icon(for buildingId: String, category: String) -> String {
        if let icon = byId[buildingId] {
            return icon
        }
        switch category {
        case "collector": return "🏗️"
        case "storage": return "📦"
        case "defense": return "🛡️"
        case "institution": return "🏛️"
        case "energy": return "⚡️"
        case "economy": return "💱"
        case "accelerator": return "⏱️"
        case "infrastructure": return "🧱"
        case "production": return "🏭"
        case "converter": return "🔧"
        default: return "◼︎"
        }
    }
}
