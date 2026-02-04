import SwiftUI

public struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @StateObject private var toastCenter = ToastCenter()
    @State private var selectedTab: ClayTab = .base
    
    public init() {
        FontRegistry.registerIfNeeded()
    }
    
    public var body: some View {
        ClayRootView(selectedTab: $selectedTab)
            .environmentObject(engine)
            .environmentObject(toastCenter)
            .onDisappear { engine.stopTimers() }
            .onReceive(NotificationCenter.default.publisher(for: .claySwitchTab)) { notification in
                if let tab = notification.object as? ClayTab {
                    selectedTab = tab
                }
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
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        ZStack {
            BackgroundView()
            VStack(spacing: 0) {
            ResourceBarView()
            Divider()
            HStack(spacing: 0) {
                SidebarView(selectedTab: $selectedTab)
                Divider()
                ZStack {
                    switch selectedTab {
                    case .base:
                        BaseView()
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
                Divider()
                RightPanelView()
            }
            Divider()
            BottomTickerView()
            }
            ToastHostView()
        }
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

public extension Notification.Name {
    static let claySwitchTab = Notification.Name("clay.switchTab")
    static let clayToast = Notification.Name("clay.toast")
}
