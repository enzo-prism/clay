import SwiftUI

public struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var spriteClock = SpriteClock()
    @State private var selectedTab: ClayTab = .base
    @State private var isBaseFocusMode: Bool = false
    @Environment(\.scenePhase) private var scenePhase
    
    public init() {
        FontRegistry.registerIfNeeded()
    }
    
    public var body: some View {
        ClayRootView(selectedTab: $selectedTab, isBaseFocusMode: $isBaseFocusMode)
            .environmentObject(engine)
            .environmentObject(toastCenter)
            .environmentObject(spriteClock)
            .onAppear {
                engine.resumeFromBackground()
                spriteClock.start()
            }
            .onDisappear {
                engine.stopTimers()
                spriteClock.stop()
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    engine.resumeFromBackground()
                    spriteClock.start()
                case .inactive, .background:
                    engine.pauseForBackground()
                    spriteClock.stop()
                @unknown default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .claySwitchTab)) { notification in
                if let tab = notification.object as? ClayTab {
                    selectedTab = tab
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clayToggleBaseFocus)) { _ in
                isBaseFocusMode.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .clayToast)) { notification in
                if let payload = notification.object as? ToastPayload {
                    toastCenter.push(message: payload.message, style: payload.style)
                }
            }
    }
}

public enum ClayTab: String, CaseIterable, Identifiable {
    case base
    case projects
    case operations
    case partnerships
    case intel
    case people
    case domains
    case achievements
    case progress
    case help
    case settings
    
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .base: return "Base"
        case .projects: return "Projects"
        case .operations: return "Operations"
        case .partnerships: return "Partnerships"
        case .intel: return "Intel"
        case .people: return "People"
        case .domains: return "Domains"
        case .achievements: return "Achievements"
        case .progress: return "Progress"
        case .help: return "Help"
        case .settings: return "Settings"
        }
    }
}

struct ClayRootView: View {
    @Binding var selectedTab: ClayTab
    @Binding var isBaseFocusMode: Bool
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        let eraTheme = EraTheme.forEra(engine.state.eraId)
        let isBaseFocus = selectedTab == .base && isBaseFocusMode
        VStack(spacing: 0) {
            ResourceBarView()
            Divider()
            if !isBaseFocus {
                GuidanceBannerRow()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("guidance_banner")
                Divider()
            }
            HStack(spacing: 0) {
                if !isBaseFocus {
                    SidebarView(selectedTab: $selectedTab)
                    Divider()
                }
                ZStack {
                    switch selectedTab {
                    case .base:
                        BaseView(isBaseFocusMode: $isBaseFocusMode)
                    case .projects:
                        ProjectsView()
                    case .operations:
                        OperationsView()
                    case .partnerships:
                        PartnershipsView()
                    case .intel:
                        IntelView()
                    case .people:
                        PeopleView()
                    case .domains:
                        DomainsView()
                    case .achievements:
                        AchievementsView()
                    case .progress:
                        ProgressViewScreen()
                    case .help:
                        HelpView()
                    case .settings:
                        SettingsViewScreen()
                    }
                }
                if !isBaseFocus {
                    Divider()
                    RightPanelView()
                }
            }
            if !isBaseFocus {
                Divider()
                BottomTickerView()
            }
        }
        // A stable minimum size avoids pathological constraint update loops when the window is
        // repeatedly asked to recompute its content-size extrema.
        .frame(minWidth: 1180, minHeight: 720)
        .background(BackgroundView())
        // Important: keep overlays from influencing window sizing.
        .overlay(alignment: .bottomTrailing) {
            ToastHostView()
        }
        .environment(\.eraTheme, eraTheme)
        .foregroundColor(ClayTheme.text)
        .font(ClayFonts.data(12))
        .preferredColorScheme(.dark)
        .alert("System Clock Changed", isPresented: Binding(get: { engine.state.pendingTimeTravelWarning }, set: { _ in })) {
            Button("Continue Anyway") {
                engine.resolveTimeTravel(allow: true)
            }
            Button("Clamp Progress") {
                engine.resolveTimeTravel(allow: false)
            }
        } message: {
            Text("System time moved backward. You can continue with the new time or clamp progress until the original time catches up.")
        }
    }
}

private struct GuidanceBannerRow: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        if let item = engine.guidanceItems().first {
            GuidanceBanner(
                title: item.title,
                message: item.detail,
                priorityColor: item.priority.tint,
                actionTitle: actionTitle(for: item.action),
                action: { perform(action: item.action) }
            )
        } else {
            GuidanceBanner(
                title: "All Clear",
                message: "No urgent actions right now.",
                priorityColor: ClayTheme.good,
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func perform(action: GuidanceAction) {
        switch action {
        case .none:
            break
        case .switchTab(let tab):
            NotificationCenter.default.post(name: .claySwitchTab, object: tab)
        case .reviewIntel:
            NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.intel)
        case .openResource:
            NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.base)
        }
    }

    private func actionTitle(for action: GuidanceAction) -> String? {
        switch action {
        case .none:
            return nil
        case .switchTab(let tab):
            switch tab {
            case .projects: return "Queue"
            case .partnerships: return "Review"
            case .intel: return "Review"
            case .base: return "Open"
            case .operations: return "Open"
            case .people, .domains, .achievements, .progress, .help, .settings:
                return "Open"
            }
        case .reviewIntel:
            return "Review"
        case .openResource:
            return "Inspect"
        }
    }
}

public extension Notification.Name {
    static let claySwitchTab = Notification.Name("clay.switchTab")
    static let clayToast = Notification.Name("clay.toast")
    static let clayToggleBaseFocus = Notification.Name("clay.toggleBaseFocus")
}
