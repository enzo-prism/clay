import SwiftUI
import CoreText

@MainActor
enum FontRegistry {
    private static var registered = false
    
    static func registerIfNeeded() {
        guard !registered else { return }
        registered = true
        registerFont(named: "SpaceGrotesk-Regular.ttf")
        registerFont(named: "SpaceGrotesk-Medium.ttf")
        registerFont(named: "IBMPlexMono-Regular.ttf")
        registerFont(named: "IBMPlexMono-Medium.ttf")
    }
    
    private static func registerFont(named name: String) {
        guard let url = Bundle.module.url(forResource: name, withExtension: nil) else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
}

enum ClayFonts {
    private static let scale: CGFloat = 1.4

    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Space Grotesk", size: size * scale).weight(weight)
    }
    
    static func data(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("IBM Plex Mono", size: size * scale).weight(weight)
    }
}
