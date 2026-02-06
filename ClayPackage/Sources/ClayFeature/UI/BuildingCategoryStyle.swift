import SwiftUI

enum BuildingCategoryStyle {
    static func color(for category: String) -> Color {
        switch category {
        case "collector": return Color(hex: "#3A7CA5")
        case "storage": return Color(hex: "#66796B")
        case "defense": return Color(hex: "#A63D40")
        case "institution": return Color(hex: "#7C6BA6")
        case "energy": return Color(hex: "#F2C14E")
        case "economy": return Color(hex: "#5AA9E6")
        case "accelerator": return Color(hex: "#4ECDC4")
        case "converter": return Color(hex: "#D67A2F")
        case "production": return Color(hex: "#3FAE7A")
        case "infrastructure": return Color(hex: "#6BA8E6")
        default: return Color(hex: "#324B5C")
        }
    }

    static func label(for category: String) -> String {
        switch category {
        case "collector": return "Collector"
        case "storage": return "Storage"
        case "defense": return "Defense"
        case "institution": return "Institution"
        case "energy": return "Energy"
        case "economy": return "Economy"
        case "accelerator": return "Accelerator"
        case "converter": return "Converter"
        case "production": return "Production"
        case "infrastructure": return "Infrastructure"
        default: return category.capitalized
        }
    }
}
