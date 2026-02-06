import SwiftUI

struct SettingsViewScreen: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        ZStack {
            BackgroundView()
            VStack(alignment: .leading, spacing: 12) {
                PageHeader(title: "Settings", subtitle: "Control offline progress and accessibility options.")
                Panel(title: "Preferences") {
                    HStack(spacing: 12) {
                        Text("Offline cap")
                            .font(ClayFonts.display(11, weight: .semibold))
                            .claySingleLine(minScale: 0.85)
                        Spacer()
                        let canDecrease = engine.state.settings.offlineCapDays > 1
                        ClayButton(isEnabled: canDecrease, blockedMessage: "Minimum 1 day") {
                            engine.setOfflineCapDays(max(1, engine.state.settings.offlineCapDays - 1))
                        } label: {
                            Text("-")
                        }
                        Text("\(engine.state.settings.offlineCapDays) days")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .allowsTightening(true)
                            .frame(minWidth: 90, alignment: .center)
                        let canIncrease = engine.state.settings.offlineCapDays < 14
                        ClayButton(isEnabled: canIncrease, blockedMessage: "Maximum 14 days") {
                            engine.setOfflineCapDays(min(14, engine.state.settings.offlineCapDays + 1))
                        } label: {
                            Text("+")
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Guidance Level")
                            .font(ClayFonts.display(10, weight: .semibold))
                            .claySingleLine(minScale: 0.85)
                        SegmentedControl(
                            segments: GuidanceLevel.allCases,
                            selection: Binding(
                                get: { engine.state.settings.guidanceLevel },
                                set: { engine.setGuidanceLevel($0) }
                            ),
                            activeTint: ClayTheme.accentWarm
                        ) { level, isSelected in
                            Text(level.label.uppercased())
                                .font(ClayFonts.display(8, weight: .semibold))
                                .foregroundColor(isSelected ? ClayTheme.accentText : ClayTheme.muted)
                                .claySingleLine(minScale: 0.7)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                        }
                    }
                    SimpleToggle(label: "Notifications", isOn: Binding(
                        get: { engine.state.settings.notificationsEnabled },
                        set: { engine.setNotificationsEnabled($0) }
                    ), identifier: "toggle_notifications")
                    SimpleToggle(label: "Colorblind Mode", isOn: Binding(
                        get: { engine.state.settings.colorblindMode },
                        set: { engine.setColorblindMode($0) }
                    ), identifier: "toggle_colorblind")
                    Text("3D base view is now the default experience.")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
            }
                .padding(.horizontal, 12)
                .accessibilityIdentifier("settings_panel")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .environment(\.colorScheme, .dark)
    }
}

private extension GuidanceLevel {
    var label: String {
        switch self {
        case .high: return "High"
        case .balanced: return "Balanced"
        case .minimal: return "Minimal"
        }
    }
}
