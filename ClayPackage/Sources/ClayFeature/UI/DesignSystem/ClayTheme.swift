import SwiftUI

enum ClayTheme {
    static let bg = Color(hex: "#0B0E13")
    static let bg2 = Color(hex: "#11141A")
    static let panel = Color(hex: "#141923")
    static let panelElevated = Color(hex: "#1A2230")
    static let stroke = Color(hex: "#243041")
    static let accent = Color(hex: "#8EC5FF")
    static let accentText = Color(hex: "#0B0E13")
    static let accentWarm = Color(hex: "#F5C66A")
    static let good = Color(hex: "#8FE3A7")
    static let bad = Color(hex: "#F38B8B")
    static let text = Color(hex: "#EAF0F7")
    static let muted = Color(hex: "#A2ACBB")
    static let shadow = Color.black.opacity(0.25)
    
    static let hudGradient = LinearGradient(
        colors: [Color(hex: "#0F131A"), Color(hex: "#0B0E13")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color(hex: "#8EC5FF"), Color(hex: "#6BA8E6")],
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
