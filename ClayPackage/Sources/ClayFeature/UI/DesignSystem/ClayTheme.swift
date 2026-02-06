import SwiftUI

enum ClayTheme {
    static let bg = Color(hex: "#1D1F1B")
    static let bg2 = Color(hex: "#242824")
    static let panel = Color(hex: "#2C312C")
    static let panelElevated = Color(hex: "#343A33")
    static let stroke = Color(hex: "#424A41")
    static let accent = Color(hex: "#9CC7B8")
    static let accentText = Color(hex: "#1B1F1C")
    static let accentWarm = Color(hex: "#E5C48B")
    static let good = Color(hex: "#9DD3A8")
    static let bad = Color(hex: "#E39A9A")
    static let text = Color(hex: "#F2EEE6")
    static let muted = Color(hex: "#C8C2B6")
    static let shadow = Color.black.opacity(0.15)
    
    static let hudGradient = LinearGradient(
        colors: [Color(hex: "#343A33"), Color(hex: "#1D1F1B")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#A6D2C2"), Color(hex: "#7FB7A3")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum ClayMetrics {
    static let radiusSmall: CGFloat = 6
    static let radius: CGFloat = 10
    static let radiusLarge: CGFloat = 16
    static let borderWidth: CGFloat = 1
    static let hudHeight: CGFloat = 52
}
