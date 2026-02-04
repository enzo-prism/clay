import Testing
import SwiftUI
import AppKit
@testable import ClayFeature

struct ContrastCalculator {
    static func contrastRatio(_ a: Color, _ b: Color) -> Double {
        guard let la = luminance(a), let lb = luminance(b) else { return 0 }
        let lighter = max(la, lb)
        let darker = min(la, lb)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func luminanceValue(_ color: Color) -> Double? {
        luminance(color)
    }
    
    private static func luminance(_ color: Color) -> Double? {
        let nsColor = NSColor(color)
        guard let rgb = nsColor.usingColorSpace(.sRGB) else { return nil }
        func transform(_ c: CGFloat) -> Double {
            let v = Double(c)
            if v <= 0.03928 { return v / 12.92 }
            return pow((v + 0.055) / 1.055, 2.4)
        }
        let r = transform(rgb.redComponent)
        let g = transform(rgb.greenComponent)
        let b = transform(rgb.blueComponent)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
}

@Test @MainActor func contrast_primaryTextOnBackground() {
    let ratio = ContrastCalculator.contrastRatio(ClayTheme.bg, ClayTheme.text)
    #expect(ratio >= 12)
}

@Test @MainActor func contrast_primaryTextOnPanel() {
    let ratio = ContrastCalculator.contrastRatio(ClayTheme.panel, ClayTheme.text)
    #expect(ratio >= 9)
}

@Test @MainActor func contrast_mutedTextOnPanel() {
    let ratio = ContrastCalculator.contrastRatio(ClayTheme.panel, ClayTheme.muted)
    #expect(ratio >= 4.5)
}

@Test @MainActor func contrast_accentOnBackground() {
    let ratio = ContrastCalculator.contrastRatio(ClayTheme.bg, ClayTheme.accent)
    #expect(ratio >= 6)
}

@Test @MainActor func contrast_goodOnBackground() {
    let ratio = ContrastCalculator.contrastRatio(ClayTheme.bg, ClayTheme.good)
    #expect(ratio >= 4.5)
}

@Test @MainActor func contrast_badOnBackground() {
    let ratio = ContrastCalculator.contrastRatio(ClayTheme.bg, ClayTheme.bad)
    #expect(ratio >= 4.5)
}

@Test @MainActor func theme_panelIsDark() {
    let lum = ContrastCalculator.luminanceValue(ClayTheme.panel) ?? 1.0
    #expect(lum <= 0.2)
}

@Test @MainActor func theme_backgroundIsDark() {
    let lum = ContrastCalculator.luminanceValue(ClayTheme.bg) ?? 1.0
    #expect(lum <= 0.12)
}

@Test @MainActor func sectionHeaderFitsRightPanel() {
    let scale: CGFloat = 1.3
    let minScale: CGFloat = 0.6
    let fontSize = 10 * scale * minScale
    let font = NSFont(name: "Space Grotesk", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
    let availableWidth: CGFloat = 180
    let titles = ["ACCELERATORS", "ACTIVE PROJECTS", "WORK CREWS"]
    for title in titles {
        let width = (title as NSString).size(withAttributes: [.font: font]).width
        #expect(width <= availableWidth)
    }
}
