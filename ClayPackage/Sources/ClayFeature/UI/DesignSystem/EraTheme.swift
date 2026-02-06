import SwiftUI

struct EraTheme {
    let id: String
    let name: String
    let backgroundTop: Color
    let backgroundBottom: Color
    let panel: Color
    let panelElevated: Color
    let stroke: Color
    let accent: Color
    let accentWarm: Color
    let good: Color
    let bad: Color
    let text: Color
    let muted: Color
    let accentGradient: LinearGradient
    let hudGradient: LinearGradient

    static let base = EraTheme(
        id: "base",
        name: "Base",
        backgroundTop: ClayTheme.bg2,
        backgroundBottom: ClayTheme.bg,
        panel: ClayTheme.panel,
        panelElevated: ClayTheme.panelElevated,
        stroke: ClayTheme.stroke,
        accent: ClayTheme.accent,
        accentWarm: ClayTheme.accentWarm,
        good: ClayTheme.good,
        bad: ClayTheme.bad,
        text: ClayTheme.text,
        muted: ClayTheme.muted,
        accentGradient: ClayTheme.accentGradient,
        hudGradient: ClayTheme.hudGradient
    )

    static func forEra(_ eraId: String) -> EraTheme {
        switch eraId {
        case "stone":
            return EraTheme(
                id: eraId,
                name: "Stone",
                backgroundTop: Color(hex: "#24211E"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        case "agrarian":
            return EraTheme(
                id: eraId,
                name: "Agrarian",
                backgroundTop: Color(hex: "#212720"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        case "metallurgy":
            return EraTheme(
                id: eraId,
                name: "Metallurgy",
                backgroundTop: Color(hex: "#26211C"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        case "industrial":
            return EraTheme(
                id: eraId,
                name: "Industrial",
                backgroundTop: Color(hex: "#20252B"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        case "planetary":
            return EraTheme(
                id: eraId,
                name: "Planetary",
                backgroundTop: Color(hex: "#1E2329"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        case "stellar":
            return EraTheme(
                id: eraId,
                name: "Stellar",
                backgroundTop: Color(hex: "#202027"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        case "galactic":
            return EraTheme(
                id: eraId,
                name: "Galactic",
                backgroundTop: Color(hex: "#1F2428"),
                backgroundBottom: ClayTheme.bg,
                panel: ClayTheme.panel,
                panelElevated: ClayTheme.panelElevated,
                stroke: ClayTheme.stroke,
                accent: ClayTheme.accent,
                accentWarm: ClayTheme.accentWarm,
                good: ClayTheme.good,
                bad: ClayTheme.bad,
                text: ClayTheme.text,
                muted: ClayTheme.muted,
                accentGradient: ClayTheme.accentGradient,
                hudGradient: ClayTheme.hudGradient
            )
        default:
            return base
        }
    }
}

private struct EraThemeKey: EnvironmentKey {
    static let defaultValue = EraTheme.base
}

extension EnvironmentValues {
    var eraTheme: EraTheme {
        get { self[EraThemeKey.self] }
        set { self[EraThemeKey.self] = newValue }
    }
}
