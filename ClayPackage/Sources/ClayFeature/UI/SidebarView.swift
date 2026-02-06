import SwiftUI
import AppKit

struct SidebarView: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.eraTheme) private var eraTheme
    @Binding var selectedTab: ClayTab
    @State private var hoveredTab: ClayTab? = nil

    private let sidebarWidth: CGFloat = 236

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CLAY")
                .font(ClayFonts.display(16, weight: .bold))
                .foregroundColor(eraTheme.accent)
                .claySingleLine(minScale: 0.8)

            SidebarSummaryCard(
                eraName: eraName,
                crewAvailable: engine.derived.availableCrewCount,
                crewTotal: engine.state.crewCount
            )

            DailyBriefingCard()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    SidebarSectionHeader(text: "Core Loop")
                    navRow(tab: .base, subtitle: baseSubtitle, badge: baseBadge)
                    navRow(tab: .projects, subtitle: projectsSubtitle, badge: projectsBadge)
                    navRow(tab: .operations, subtitle: operationsSubtitle, badge: operationsBadge)
                    navRow(tab: .partnerships, subtitle: partnershipsSubtitle, badge: partnershipsBadge)

                    SidebarSectionHeader(text: "Intel & People")
                    navRow(tab: .intel, subtitle: intelSubtitle, badge: intelBadge)
                    navRow(tab: .people, subtitle: peopleSubtitle, badge: peopleBadge)

                    SidebarSectionHeader(text: "Progression")
                    navRow(tab: .progress, subtitle: progressSubtitle, badge: nil)
                    navRow(tab: .domains, subtitle: domainsSubtitle, badge: nil)
                    navRow(tab: .achievements, subtitle: achievementsSubtitle, badge: nil)

                    SidebarSectionHeader(text: "Support")
                    navRow(tab: .help, subtitle: "Guides, tips, and systems", badge: nil)
                    navRow(tab: .settings, subtitle: "Preferences and accessibility", badge: nil)
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Divider()

            SidebarQuickActions(actions: quickActions)
        }
        .accessibilityIdentifier("sidebar")
        .padding(12)
        .frame(width: sidebarWidth)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        eraTheme.panel.opacity(0.92),
                        eraTheme.panelElevated.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            Rectangle()
                .fill(eraTheme.stroke.opacity(0.6))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private func navRow(tab: ClayTab, subtitle: String, badge: SidebarBadgeData?) -> some View {
        let isHovered = hoveredTab == tab
        let isSelected = selectedTab == tab
        return SidebarNavRow(
            title: tab.title,
            subtitle: subtitle,
            symbolName: symbolName(for: tab),
            fallbackPath: iconPath(for: tab),
            badge: badge,
            isSelected: isSelected,
            isHovered: isHovered
        ) {
            selectedTab = tab
        }
        .accessibilityIdentifier("nav_\(tab.rawValue)")
        .onHover { hovering in
            hoveredTab = hovering ? tab : nil
        }
    }

    private var eraName: String {
        engine.content.erasById[engine.state.eraId]?.name ?? "Unknown Era"
    }

    private var baseSubtitle: String {
        let buildings = engine.state.buildings.count
        let factor = formatFactor(engine.derived.logistics.logisticsFactor)
        return "Buildings \(buildings) • Logistics x\(factor)"
    }

    private var baseBadge: SidebarBadgeData? {
        engine.projectAdvisorMessage() != nil ? SidebarBadgeData(text: "!", color: eraTheme.accentWarm) : nil
    }

    private var projectsSubtitle: String {
        "Active \(researchActiveCount) • Queue \(queuedProjectsCount)"
    }

    private var projectsBadge: SidebarBadgeData? {
        if engine.derived.availableCrewCount > 0 && researchActiveCount == 0 && queuedProjectsCount == 0 {
            return SidebarBadgeData(text: "Idle", color: ClayTheme.muted)
        }
        return nil
    }

    private var operationsSubtitle: String {
        "Active \(dispatchActiveCount) • Ready \(dispatchReadyCount)"
    }

    private var operationsBadge: SidebarBadgeData? {
        dispatchReadyCount > 0 ? SidebarBadgeData(text: "\(dispatchReadyCount)", color: ClayTheme.good) : nil
    }

    private var partnershipsSubtitle: String {
        "Active \(activeContractCount) • Expiring \(expiringContractCount)"
    }

    private var partnershipsBadge: SidebarBadgeData? {
        expiringContractCount > 0 ? SidebarBadgeData(text: "\(expiringContractCount)", color: ClayTheme.accentWarm) : nil
    }

    private var intelSubtitle: String {
        let raid = Int(engine.derived.risk.raidChancePerHour * 100)
        let status = engine.state.eventChains.pendingEventChainId == nil ? "Clear" : "Decision"
        return "Raid/h \(raid)% • Events \(status)"
    }

    private var intelBadge: SidebarBadgeData? {
        engine.state.eventChains.pendingEventChainId != nil ? SidebarBadgeData(text: "Decision", color: ClayTheme.accentWarm) : nil
    }

    private var peopleSubtitle: String {
        "Roster \(engine.state.people.recruitedIds.count)/\(engine.state.people.maxRoster) • Allies \(allyCount)"
    }

    private var peopleBadge: SidebarBadgeData? {
        availableRecruitsCount > 0 ? SidebarBadgeData(text: "\(availableRecruitsCount)", color: ClayTheme.accent) : nil
    }

    private var progressSubtitle: String {
        "Era \(eraName) • Keystone \(keystoneStatus)"
    }

    private var domainsSubtitle: String {
        "Top Tier \(topDomainTier) • Active \(unlockedDomainCount)/\(engine.content.pack.domains.count)"
    }

    private var achievementsSubtitle: String {
        "Unlocked \(engine.state.achievementsUnlocked.count)/\(engine.content.pack.achievements.count)"
    }

    private var researchActiveCount: Int {
        engine.state.activeProjects.filter { $0.source == .research }.count
    }

    private var queuedProjectsCount: Int {
        engine.state.queuedProjects.count
    }

    private var dispatchActiveCount: Int {
        engine.state.dispatches.filter { $0.status == .active }.count
    }

    private var dispatchReadyCount: Int {
        engine.state.dispatches.filter { $0.status != .active }.count
    }

    private var activeContractCount: Int {
        engine.state.factionStates.values.reduce(0) { $0 + $1.activeContracts.count }
    }

    private var expiringContractCount: Int {
        engine.state.factionStates.values.flatMap(\.activeContracts).filter { $0.remainingSeconds < 3600 }.count
    }

    private var allyCount: Int {
        engine.state.metahumans.values.filter { $0.disposition == .ally }.count
    }

    private var availableRecruitsCount: Int {
        engine.availablePeople().count
    }

    private var keystoneStatus: String {
        guard let era = engine.content.erasById[engine.state.eraId] else { return "Unknown" }
        let projectIds = era.keystoneProjectIds ?? [era.keystoneProjectId]
        if projectIds.contains(where: { engine.state.completedProjectIds.contains($0) }) {
            return "Complete"
        }
        if engine.state.activeProjects.contains(where: { projectIds.contains($0.projectId) }) {
            return "Active"
        }
        let ready = projectIds.contains { id in
            guard let project = engine.content.projectsById[id] else { return false }
            return engine.projectBlockReason(project) == nil
        }
        if ready {
            return "Ready"
        }
        return "Locked"
    }

    private var topDomainTier: Int {
        engine.state.domainState.unlockedTiersByDomain.values.max() ?? 0
    }

    private var unlockedDomainCount: Int {
        engine.state.domainState.unlockedTiersByDomain.values.filter { $0 > 0 }.count
    }

    private var quickActions: [SidebarQuickAction] {
        var actions: [SidebarQuickAction] = []

        let cacheTotal = engine.state.collector.storedByResource.values.reduce(0, +)
        if cacheTotal > 0 {
            actions.append(
                SidebarQuickAction(
                    title: "Collect Cache",
                    subtitle: "\(cacheTotal.clayFormatted) ready",
                    iconPath: "KenneySelected/Icons/icon_save.png",
                    tint: ClayTheme.accentWarm
                ) {
                    engine.collectCache()
                }
            )
        }

        let collectableDispatches = engine.state.dispatches.filter { $0.status != .active }
        if !collectableDispatches.isEmpty {
            actions.append(
                SidebarQuickAction(
                    title: "Collect Dispatches",
                    subtitle: "\(collectableDispatches.count) ready",
                    iconPath: "KenneySelected/Icons/icon_fastforward.png",
                    tint: ClayTheme.good
                ) {
                    let ids = collectableDispatches.map(\.id)
                    for id in ids {
                        engine.collectDispatch(id: id)
                    }
                }
            )
        }

        if engine.state.eventChains.pendingEventChainId != nil {
            actions.append(
                SidebarQuickAction(
                    title: "Review Intel",
                    subtitle: "Decision pending",
                    iconPath: "KenneySelected/Icons/icon_info.png",
                    tint: ClayTheme.accentWarm
                ) {
                    selectedTab = .intel
                }
            )
        }

        if engine.derived.availableCrewCount > 0 && engine.state.queuedProjects.isEmpty {
            actions.append(
                SidebarQuickAction(
                    title: "Queue Projects",
                    subtitle: "Crew free",
                    iconPath: "KenneySelected/Icons/icon_wrench.png",
                    tint: ClayTheme.accent
                ) {
                    selectedTab = .projects
                }
            )
        }

        if expiringContractCount > 0 {
            actions.append(
                SidebarQuickAction(
                    title: "Renew Contracts",
                    subtitle: "\(expiringContractCount) expiring",
                    iconPath: "KenneySelected/Icons/icon_cart.png",
                    tint: ClayTheme.accentWarm
                ) {
                    selectedTab = .partnerships
                }
            )
        }

        return actions
    }

    private func formatFactor(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func iconPath(for tab: ClayTab) -> String? {
        switch tab {
        case .base:
            return "KenneySelected/Icons/icon_home.png"
        case .projects:
            return "KenneySelected/Icons/icon_wrench.png"
        case .operations:
            return "KenneySelected/Icons/icon_fastforward.png"
        case .partnerships:
            return "KenneySelected/Icons/icon_cart.png"
        case .intel:
            return "KenneySelected/Icons/icon_info.png"
        case .people:
            return "KenneySelected/Icons/icon_user.png"
        case .domains:
            return "KenneySelected/Icons/icon_bars.png"
        case .achievements:
            return "KenneySelected/Icons/icon_power.png"
        case .progress:
            return "KenneySelected/Icons/icon_target.png"
        case .help:
            return "KenneySelected/Icons/icon_info.png"
        case .settings:
            return "KenneySelected/Icons/icon_gear.png"
        }
    }

    private func symbolName(for tab: ClayTab) -> String {
        switch tab {
        case .base:
            return "house"
        case .projects:
            return "hammer"
        case .operations:
            return "paperplane"
        case .partnerships:
            return "link"
        case .intel:
            return "eye"
        case .people:
            return "person.2"
        case .domains:
            return "square.grid.2x2"
        case .achievements:
            return "star.circle"
        case .progress:
            return "chart.line.uptrend.xyaxis"
        case .settings:
            return "gearshape"
        case .help:
            return "questionmark.circle"
        }
    }
}

private struct DailyBriefingCard: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.eraTheme) private var eraTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Briefing".uppercased())
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(eraTheme.accent)
                .claySingleLine(minScale: 0.8)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Idle Crew")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.85)
                    Text("\(engine.derived.availableCrewCount)")
                        .font(ClayFonts.display(11, weight: .semibold))
                        .foregroundColor(engine.derived.availableCrewCount > 0 ? ClayTheme.accentWarm : ClayTheme.muted)
                        .monospacedDigit()
                        .claySingleLine(minScale: 0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bottleneck")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.85)
                    Text(bottleneckLabel)
                        .font(ClayFonts.display(11, weight: .semibold))
                        .foregroundColor(bottleneckTint)
                        .claySingleLine(minScale: 0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Raid Risk")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.85)
                    Text("\(raidRisk)%")
                        .font(ClayFonts.display(11, weight: .semibold))
                        .foregroundColor(raidRisk > 12 ? ClayTheme.bad : ClayTheme.good)
                        .monospacedDigit()
                        .claySingleLine(minScale: 0.8)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }

    private var raidRisk: Int {
        Int(engine.derived.risk.raidChancePerHour * 100)
    }

    private var bottleneckLabel: String {
        guard let worst = engine.derived.resourceRatesPerHour.min(by: { $0.value < $1.value }) else {
            return "Stable"
        }
        let name = engine.content.resourcesById[worst.key]?.name ?? worst.key.capitalized
        return worst.value < 0 ? name : "Stable"
    }

    private var bottleneckTint: Color {
        guard let worst = engine.derived.resourceRatesPerHour.min(by: { $0.value < $1.value }) else {
            return ClayTheme.good
        }
        return worst.value < 0 ? ClayTheme.bad : ClayTheme.good
    }
}

private struct SidebarSummaryCard: View {
    let eraName: String
    let crewAvailable: Int
    let crewTotal: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("COMMAND DECK")
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                    .claySingleLine(minScale: 0.75)
                Spacer(minLength: 0)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ERA")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.85)
                    Text(eraName)
                        .font(ClayFonts.display(11, weight: .semibold))
                        .foregroundColor(ClayTheme.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("CREWS")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.85)
                    Text("\(crewAvailable) / \(crewTotal)")
                        .font(ClayFonts.display(11, weight: .semibold))
                        .foregroundColor(crewAvailable > 0 ? ClayTheme.good : ClayTheme.muted)
                        .claySingleLine(minScale: 0.8)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }
}

private struct SidebarSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(ClayFonts.display(9, weight: .semibold))
            .foregroundColor(ClayTheme.muted)
            .claySingleLine(minScale: 0.75)
    }
}

private struct SidebarNavRow: View {
    let title: String
    let subtitle: String
    let symbolName: String?
    let fallbackPath: String?
    let badge: SidebarBadgeData?
    let isSelected: Bool
    let isHovered: Bool
    let action: () -> Void
    @Environment(\.eraTheme) private var eraTheme

    var body: some View {
        let fill = isSelected ? eraTheme.panelElevated : (isHovered ? eraTheme.panelElevated.opacity(0.6) : Color.clear)
        let strokeColor = isSelected ? eraTheme.accent.opacity(0.7) : (isHovered ? eraTheme.stroke.opacity(0.9) : eraTheme.stroke.opacity(0.5))
        let iconTint = isSelected ? eraTheme.accent : (isHovered ? eraTheme.text : eraTheme.muted)
        

        Button(action: action) {
            HStack(spacing: 10) {
                SidebarSymbolIconView(symbolName: symbolName, fallbackPath: fallbackPath, size: 16, tint: iconTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(ClayFonts.display(10, weight: .semibold))
                        .foregroundColor(eraTheme.text)
                        .claySingleLine(minScale: 0.7)
                    Text(subtitle)
                        .font(ClayFonts.data(9))
                        .foregroundColor(eraTheme.muted)
                        .claySingleLine(minScale: 0.7)
                }
                Spacer(minLength: 0)
                if let badge {
                    SidebarBadge(text: badge.text, color: badge.color)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(navBackground(fill: fill))
            .overlay(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(eraTheme.accent)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .opacity(isSelected ? 1 : 0),
                alignment: .leading
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func navBackground(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
            .fill(fill)
    }
}

private struct SidebarSymbolIconView: View {
    let symbolName: String?
    let fallbackPath: String?
    let size: CGFloat
    let tint: Color

    var body: some View {
        if let symbolName, symbolAvailable(symbolName) {
            Image(systemName: symbolName)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
        } else {
            KenneyIconView(path: fallbackPath, size: size, tint: tint)
        }
    }

    private func symbolAvailable(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}

private struct SidebarBadgeData {
    let text: String
    let color: Color
}

private struct SidebarBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text.uppercased())
            .font(ClayFonts.display(8, weight: .bold))
            .foregroundColor(color)
            .claySingleLine(minScale: 0.7)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color.opacity(0.4), lineWidth: 1)
            )
    }
}

private struct SidebarQuickAction: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let iconPath: String?
    let tint: Color
    let action: () -> Void
}

private struct SidebarQuickActions: View {
    let actions: [SidebarQuickAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK ACTIONS")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.75)

            if actions.isEmpty {
                Text("No actions available.")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .clayTwoLines(minScale: 0.9)
                    .padding(.vertical, 6)
            } else {
                ForEach(actions) { action in
                    ClayButton(isEnabled: true, active: false) {
                        action.action()
                    } label: {
                        HStack(spacing: 8) {
                            KenneyIconView(path: action.iconPath, size: 12, tint: action.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title.uppercased())
                                    .font(ClayFonts.display(9, weight: .semibold))
                                    .foregroundColor(ClayTheme.text)
                                    .claySingleLine(minScale: 0.75)
                                if let subtitle = action.subtitle {
                                    Text(subtitle)
                                        .font(ClayFonts.data(9))
                                        .foregroundColor(ClayTheme.muted)
                                        .claySingleLine(minScale: 0.75)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }
}
