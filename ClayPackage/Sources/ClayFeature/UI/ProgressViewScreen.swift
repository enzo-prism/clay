import SwiftUI

struct ProgressViewScreen: View {
    @EnvironmentObject private var engine: GameEngine
    @State private var expandedEraId: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Progress", subtitle: "A deeper look at eras, keystones, and your next breakthrough.")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NextMilestoneCard()
                    EraOverviewSection(expandedEraId: $expandedEraId)
                    EraLadderSection()
                    NextEraFocusSection()
                    KardashevSection()
                    WorldStatePanel()
                    PoliciesPanel()
                    MetahumansPanel()
                    PrestigePanel()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
    }
}

private struct NextMilestoneCard: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        SoftCard(title: "Next Milestone") {
            if let project = nextMilestoneProject() {
                HStack(spacing: 10) {
                    PixelSpriteView(spriteId: "work", size: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                            .font(ClayFonts.display(11, weight: .semibold))
                            .claySingleLine(minScale: 0.75)
                        Text(project.description)
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.muted)
                            .clayTwoLines(minScale: 0.9)
                    }
                    Spacer(minLength: 0)
                    ClayButton(isEnabled: true, active: true) {
                        NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.projects)
                    } label: {
                        Text("Open Projects")
                    }
                }
            } else {
                Text("You are at the frontier. Focus on megaprojects and legacy upgrades.")
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
            }
        }
    }

    private func nextMilestoneProject() -> ProjectDefinition? {
        let eras = engine.content.pack.eras.sorted { $0.sortOrder < $1.sortOrder }
        let currentIndex = eras.firstIndex(where: { $0.id == engine.state.eraId }) ?? 0
        let nextIndex = min(eras.count - 1, currentIndex + 1)
        let nextEra = eras[safe: nextIndex]
        let projectIds = nextEra?.keystoneProjectIds ?? (nextEra.map { [$0.keystoneProjectId] } ?? [])
        for projectId in projectIds {
            if engine.state.completedProjectIds.contains(projectId) { continue }
            if let project = engine.content.projectsById[projectId] {
                return project
            }
        }
        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private struct EraOverviewSection: View {
    @EnvironmentObject private var engine: GameEngine
    @Binding var expandedEraId: String?

    private var eras: [EraDefinition] {
        engine.content.pack.eras.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Era Timeline")
            ForEach(eras) { era in
                EraProgressCard(era: era, isExpanded: expandedEraId == era.id) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedEraId = expandedEraId == era.id ? nil : era.id
                    }
                }
            }
        }
    }
}

private struct NextEraFocusSection: View {
    @EnvironmentObject private var engine: GameEngine

    private var eras: [EraDefinition] {
        engine.content.pack.eras.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentEraIndex: Int {
        eras.firstIndex(where: { $0.id == engine.state.eraId }) ?? 0
    }

    private var nextEra: EraDefinition? {
        let nextIndex = min(eras.count - 1, currentEraIndex + 1)
        if nextIndex == currentEraIndex { return nil }
        return eras[nextIndex]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Next Era Focus")
            if let nextEra {
                if let options = nextEra.keystoneProjectIds, options.count > 1 {
                    let names = options.compactMap { engine.content.projectsById[$0]?.name }
                    if !names.isEmpty {
                        Panel {
                            Text("Any of: \(names.joined(separator: " / "))")
                                .font(ClayFonts.data(9))
                                .foregroundColor(ClayTheme.muted)
                        }
                    }
                }
                EraFocusCard(era: nextEra)
            } else {
                Panel {
                    Text("You are in the final era. Complete the remaining megaprojects to finish the Kardashev chain.")
                        .font(ClayFonts.data(11))
                        .foregroundColor(ClayTheme.muted)
                }
            }
        }
    }
}

private struct EraLadderSection: View {
    @EnvironmentObject private var engine: GameEngine

    private var eras: [EraDefinition] {
        engine.content.pack.eras.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var currentIndex: Int {
        eras.firstIndex(where: { $0.id == engine.state.eraId }) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Era Distance Map")
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(eras.enumerated()), id: \.element.id) { index, era in
                    EraLadderRow(era: era, index: index, currentIndex: currentIndex, totalCount: eras.count)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .fill(ClayTheme.panelElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
            )
        }
    }
}

private struct EraLadderRow: View {
    let era: EraDefinition
    let index: Int
    let currentIndex: Int
    let totalCount: Int

    private var status: EraStatus {
        if index < currentIndex { return .completed }
        if index == currentIndex { return .current }
        return .locked
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                if index < totalCount - 1 {
                    Rectangle()
                        .fill(ClayTheme.stroke.opacity(0.6))
                        .frame(width: 2, height: 14)
                }
            }
            Text(era.name)
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(status == .locked ? ClayTheme.muted : ClayTheme.text)
                .claySingleLine(minScale: 0.75)
            Spacer()
            if index > currentIndex {
                Text("+\(index - currentIndex)")
                    .font(ClayFonts.data(9, weight: .semibold))
                    .foregroundColor(ClayTheme.muted)
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case .current:
            return ClayTheme.good
        case .completed:
            return ClayTheme.accent
        case .locked:
            return ClayTheme.muted
        }
    }
}

private struct KardashevSection: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Kardashev Chain")
            KardashevRow(title: "Type I: Planetary Energy Grid", completed: engine.state.flags["type_i_complete"] == true)
            KardashevRow(title: "Type II: Stellar Megastructure", completed: engine.state.flags["type_ii_complete"] == true)
            KardashevRow(title: "Type III: Galactic Harness Network", completed: engine.state.flags["type_iii_complete"] == true)
        }
    }
}

private struct WorldStatePanel: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "World State")
            Panel {
                VStack(alignment: .leading, spacing: 8) {
                    WorldStateRow(
                        title: "Cohesion",
                        value: engine.state.cohesion,
                        description: "Social unity that stabilizes output and reduces unrest.",
                        tint: ClayTheme.good
                    )
                    WorldStateRow(
                        title: "Biosphere",
                        value: engine.state.biosphere,
                        description: "Planet health that boosts Food + Knowledge when protected.",
                        tint: ClayTheme.accentWarm
                    )
                }
            }
        }
    }
}

private struct WorldStateRow: View {
    let title: String
    let value: Double
    let description: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(tint)
                    .claySingleLine(minScale: 0.75)
            }
            SimpleProgressBar(value: min(1.0, max(0, value)))
            Text(description)
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
                .clayTwoLines(minScale: 0.9)
        }
    }
}

private struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(ClayFonts.display(10, weight: .semibold))
            .foregroundColor(ClayTheme.accent)
            .claySingleLine(minScale: 0.8)
    }
}

private struct EraProgressCard: View {
    @EnvironmentObject private var engine: GameEngine
    let era: EraDefinition
    let isExpanded: Bool
    let onToggle: () -> Void

    private var keystoneProjects: [ProjectDefinition] {
        let ids = era.keystoneProjectIds ?? [era.keystoneProjectId]
        return ids.compactMap { engine.content.projectsById[$0] }
    }

    private var status: EraStatus {
        if engine.state.eraId == era.id { return .current }
        if engine.isEraComplete(era) { return .completed }
        return .locked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack {
                    Text(era.name)
                        .font(ClayFonts.display(11, weight: .semibold))
                        .claySingleLine(minScale: 0.75)
                    Spacer()
                    EraStatusPill(status: status)
                }
            }
            .buttonStyle(.plain)

            if !keystoneProjects.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(keystoneProjects) { project in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(project.name)
                                .font(ClayFonts.display(10, weight: .semibold))
                                .foregroundColor(ClayTheme.text)
                                .claySingleLine(minScale: 0.75)
                            EraProgressBars(project: project)
                        }
                        .padding(.top, 2)
                    }
                }
            }

            if isExpanded {
                Text(era.description)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                if !keystoneProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(keystoneProjects.count > 1 ? "Keystone Options" : "Keystone")
                            .font(ClayFonts.display(10, weight: .semibold))
                            .claySingleLine(minScale: 0.8)
                        ForEach(keystoneProjects) { project in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(ClayFonts.display(10, weight: .semibold))
                                    .claySingleLine(minScale: 0.75)
                                Text(project.description)
                                    .font(ClayFonts.data(9))
                                    .foregroundColor(ClayTheme.muted)
                                    .clayTwoLines(minScale: 0.9)
                                EraCostList(costs: project.costs)
                            }
                        }
                    }
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
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct EraFocusCard: View {
    @EnvironmentObject private var engine: GameEngine
    let era: EraDefinition

    private var keystoneProjects: [ProjectDefinition] {
        let ids = era.keystoneProjectIds ?? [era.keystoneProjectId]
        return ids.compactMap { engine.content.projectsById[$0] }
    }

    private var activeProjectIds: Set<String> {
        Set(engine.state.activeProjects.map(\.projectId))
    }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(era.name)
                        .font(ClayFonts.display(12, weight: .bold))
                        .claySingleLine(minScale: 0.75)
                    Spacer()
                    if engine.isEraComplete(era) {
                        Text("READY")
                            .font(ClayFonts.display(9, weight: .semibold))
                            .foregroundColor(ClayTheme.good)
                            .claySingleLine(minScale: 0.7)
                    } else {
                        Text("IN PROGRESS")
                            .font(ClayFonts.display(9, weight: .semibold))
                            .foregroundColor(ClayTheme.accentWarm)
                            .claySingleLine(minScale: 0.7)
                    }
                }
                Text(era.description)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                if !keystoneProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        if keystoneProjects.count > 1 {
                            Text("Choose one path to advance:")
                                .font(ClayFonts.data(9))
                                .foregroundColor(ClayTheme.muted)
                        } else {
                            Text("Keystone Project")
                                .font(ClayFonts.display(10, weight: .semibold))
                                .claySingleLine(minScale: 0.8)
                        }
                        ForEach(keystoneProjects) { keystone in
                            let active = activeProjectIds.contains(keystone.id)
                            let canStart = engine.projectBlockReason(keystone) == nil
                            VStack(alignment: .leading, spacing: 6) {
                                Text(keystone.name)
                                    .font(ClayFonts.display(11, weight: .semibold))
                                    .claySingleLine(minScale: 0.75)
                                Text(keystone.description)
                                    .font(ClayFonts.data(9))
                                    .foregroundColor(ClayTheme.muted)
                                    .clayTwoLines(minScale: 0.9)
                                EraProgressBars(project: keystone)
                                EraCostList(costs: keystone.costs)
                                EraProjectionRow(project: keystone)
                                EraRecommendationRow(project: keystone)
                                HStack {
                                    if let activeProject = engine.state.activeProjects.first(where: { $0.projectId == keystone.id }) {
                                        Text("Time Remaining: \(activeProject.remainingSeconds.clayTimeString)")
                                            .font(ClayFonts.data(9))
                                            .foregroundColor(ClayTheme.muted)
                                            .monospacedDigit()
                                            .claySingleLine(minScale: 0.8)
                                    } else {
                                        Text("Duration: \(keystone.durationSeconds.clayTimeString)")
                                            .font(ClayFonts.data(9))
                                            .foregroundColor(ClayTheme.muted)
                                            .monospacedDigit()
                                            .claySingleLine(minScale: 0.8)
                                    }
                                    Spacer()
                                    if !engine.state.completedProjectIds.contains(keystone.id) {
                                        ClayButton(isEnabled: canStart, blockedMessage: engine.projectBlockReason(keystone)) {
                                            engine.startProject(projectId: keystone.id, source: .research)
                                        } label: {
                                            Text(active ? "In Progress" : "Start Keystone")
                                        }
                                        .disabled(active)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EraProgressBars: View {
    @EnvironmentObject private var engine: GameEngine
    let project: ProjectDefinition

    private var resourceReadiness: Double {
        guard !project.costs.isEmpty else { return 1 }
        return project.costs.map { resourceId, cost in
            let current = engine.state.resources[resourceId]?.amount ?? 0
            return min(1, current / max(1, cost))
        }.min() ?? 0
    }

    private var projectProgress: Double {
        if engine.state.completedProjectIds.contains(project.id) { return 1 }
        if let active = engine.state.activeProjects.first(where: { $0.projectId == project.id }) {
            return max(0, min(1, 1 - (active.remainingSeconds / active.totalSeconds)))
        }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressRow(label: "Resource Readiness", value: resourceReadiness)
            ProgressRow(label: "Keystone Progress", value: projectProgress)
        }
    }
}

private struct ProgressRow: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(ClayFonts.data(9, weight: .semibold))
                    .foregroundColor(ClayTheme.text)
            }
            SimpleProgressBar(value: value, isActive: true)
        }
    }
}

private struct EraCostList: View {
    @EnvironmentObject private var engine: GameEngine
    let costs: ResourceAmount

    var body: some View {
        if costs.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                ForEach(costs.keys.sorted(), id: \.self) { resourceId in
                    let required = costs[resourceId, default: 0]
                    let current = engine.state.resources[resourceId]?.amount ?? 0
                    HStack {
                        ResourceIconView(resourceId: resourceId, size: 12, tint: ClayTheme.text)
                        Text("\(current.clayFormatted) / \(required.clayFormatted)")
                            .font(ClayFonts.data(9))
                            .foregroundColor(current >= required ? ClayTheme.good : ClayTheme.accentWarm)
                        Spacer()
                    }
                }
            }
        )
    }
}

private struct EraProjectionRow: View {
    @EnvironmentObject private var engine: GameEngine
    let project: ProjectDefinition

    var body: some View {
        let projection = projectedTime(project: project)
        HStack {
            Text("Projected time to start")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
            Spacer()
            Text(projection)
                .font(ClayFonts.data(9, weight: .semibold))
                .foregroundColor(ClayTheme.text)
        }
    }

    private func projectedTime(project: ProjectDefinition) -> String {
        var maxHours: Double = 0
        var unknown = false
        for (resourceId, cost) in project.costs {
            let current = engine.state.resources[resourceId]?.amount ?? 0
            if current >= cost { continue }
            let rate = engine.derived.resourceRatesPerHour[resourceId, default: 0]
            if rate <= 0 {
                unknown = true
                continue
            }
            let hours = (cost - current) / rate
            maxHours = max(maxHours, hours)
        }
        if unknown && maxHours == 0 {
            return "Unknown"
        }
        if maxHours <= 0 {
            return "Ready"
        }
        return TimeInterval(maxHours * 3600).clayTimeString
    }
}

private struct EraRecommendationRow: View {
    @EnvironmentObject private var engine: GameEngine
    let project: ProjectDefinition

    var body: some View {
        let recommendation = recommendAction(project: project)
        HStack(alignment: .top, spacing: 8) {
            Text("Recommended next step:")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
            Spacer()
            Text(recommendation.text)
                .font(ClayFonts.data(9, weight: .semibold))
                .foregroundColor(ClayTheme.text)
                .multilineTextAlignment(.trailing)
        }
        if let tab = recommendation.tab {
            ClayButton(isEnabled: true, active: true) {
                NotificationCenter.default.post(name: .claySwitchTab, object: tab)
            } label: {
                Text(recommendation.button)
            }
        }
    }

    private func recommendAction(project: ProjectDefinition) -> (text: String, button: String, tab: ClayTab?) {
        if engine.projectBlockReason(project) == nil {
            return ("Start the keystone project now.", "Go to Projects", .projects)
        }
        let deficits = project.costs.map { resourceId, cost -> (String, Double) in
            let current = engine.state.resources[resourceId]?.amount ?? 0
            return (resourceId, max(0, cost - current))
        }.sorted { $0.1 > $1.1 }
        if let top = deficits.first, top.1 > 0 {
            let name = engine.content.resourcesById[top.0]?.name ?? top.0.capitalized
            return ("Build more \(name) production or storage.", "Go to Base", .base)
        }
        return ("Queue supporting projects to speed things up.", "Go to Projects", .projects)
    }
}

private enum EraStatus {
    case current
    case completed
    case locked
}

private struct EraStatusPill: View {
    let status: EraStatus

    var body: some View {
        let label: String
        let color: Color
        switch status {
        case .current:
            label = "CURRENT"
            color = ClayTheme.good
        case .completed:
            label = "COMPLETED"
            color = ClayTheme.accent
        case .locked:
            label = "LOCKED"
            color = ClayTheme.muted
        }
        return Text(label)
            .font(ClayFonts.display(9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(ClayTheme.panel)
            )
    }
}

struct KardashevRow: View {
    let title: String
    let completed: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(ClayFonts.display(11, weight: .semibold))
            Spacer()
            Text(completed ? "COMPLETE" : "INCOMPLETE")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(completed ? ClayTheme.good : ClayTheme.accentWarm)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

struct PoliciesPanel: View {
    @EnvironmentObject private var engine: GameEngine

    private var slots: [String] {
        Array(Set(engine.content.pack.policies.map { $0.slot })).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POLICIES")
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
                .claySingleLine(minScale: 0.8)
            ForEach(slots, id: \.self) { slot in
                PolicySlotRow(slot: slot)
            }
        }
    }
}

struct PolicySlotRow: View {
    @EnvironmentObject private var engine: GameEngine
    let slot: String

    var body: some View {
        let activeId = engine.state.policyState.activePoliciesBySlot[slot]
        let policies = engine.content.pack.policies.filter { $0.slot == slot }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(slot.uppercased())
                    .font(ClayFonts.display(9, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Spacer()
                if activeId != nil {
                    Text("ACTIVE")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.good)
                        .claySingleLine(minScale: 0.75)
                } else {
                    Text("INACTIVE")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.75)
                }
            }
            ForEach(policies) { policy in
                let isActive = activeId == policy.id
                let blockReason = isActive ? nil : engine.policyBlockReason(policy)
                let isEnabled = blockReason == nil
                ClayButton(isEnabled: isEnabled, active: isActive, blockedMessage: blockReason) {
                    engine.setPolicy(slot: slot, policyId: isActive ? nil : policy.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(policy.name)
                                .font(ClayFonts.display(10, weight: .semibold))
                                .claySingleLine(minScale: 0.75)
                            Text(policy.description)
                                .font(ClayFonts.data(9))
                                .foregroundColor(ClayTheme.muted)
                        }
                        Spacer()
                        if isActive {
                            Text("SELECTED")
                                .font(ClayFonts.display(9, weight: .semibold))
                                .foregroundColor(ClayTheme.accent)
                                .claySingleLine(minScale: 0.75)
                        }
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

struct PrestigePanel: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        let breakdown = engine.legacyGainBreakdown()
        VStack(alignment: .leading, spacing: 8) {
            Text("PRESTIGE")
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
            HStack {
                Text("Legacy Points")
                    .font(ClayFonts.display(10, weight: .semibold))
                Spacer()
                Text("\(engine.state.prestige.legacyPoints)")
                    .font(ClayFonts.display(10, weight: .semibold))
            }
            Text("Gain on Ascend: \(engine.availableLegacyGain())")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
            VStack(alignment: .leading, spacing: 4) {
                Text("Breakdown")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                breakdownRow(label: "Era keystones", value: breakdown.eraPoints)
                breakdownRow(label: "Domain tiers", value: breakdown.domainBonus)
                breakdownRow(label: "Achievements", value: breakdown.achievementBonus)
                breakdownRow(label: "Energy bonus", value: breakdown.energyBonus)
                if let hint = nextLegacyHint(domainTotal: domainTierTotal(), achievementCount: engine.state.achievementsUnlocked.count) {
                    Text(hint)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(engine.content.pack.legacyUpgrades) { upgrade in
                    let owned = engine.state.prestige.legacyUpgrades.contains(upgrade.id)
                    let canAfford = engine.state.prestige.legacyPoints >= upgrade.cost
                    let blockReason: String? = owned ? "Already owned" : (canAfford ? nil : "Insufficient Legacy Points")
                    let isEnabled = blockReason == nil
                    ClayButton(isEnabled: isEnabled, active: isEnabled, blockedMessage: blockReason) {
                        engine.purchaseLegacyUpgrade(upgrade.id)
                    } label: {
                        Text(upgrade.name)
                    }
                }
            }
            ClayButton(isEnabled: true, active: true) {
                engine.ascend()
            } label: {
                Text("Ascend")
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }

    private func breakdownRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
            Spacer()
            Text("\(value)")
                .font(ClayFonts.data(9, weight: .semibold))
                .foregroundColor(ClayTheme.text)
        }
    }

    private func domainTierTotal() -> Int {
        engine.state.domainState.unlockedTiersByDomain.values.reduce(0, +)
    }

    private func nextLegacyHint(domainTotal: Int, achievementCount: Int) -> String? {
        let domainRemainder = domainTotal % 3
        let achievementRemainder = achievementCount % 4
        let nextDomain = domainRemainder == 0 ? 3 : 3 - domainRemainder
        let nextAchievement = achievementRemainder == 0 ? 4 : 4 - achievementRemainder
        if nextDomain <= nextAchievement {
            return "Next bonus in \(nextDomain) domain tier\(nextDomain == 1 ? "" : "s")."
        }
        return "Next bonus in \(nextAchievement) achievement\(nextAchievement == 1 ? "" : "s")."
    }
}

struct MetahumansPanel: View {
    @EnvironmentObject private var engine: GameEngine
    
    private var metahumans: [MetahumanDefinition] {
        engine.content.pack.metahumans
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("METAHUMANS")
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
            ForEach(Array(metahumans.enumerated()), id: \.offset) { _, meta in
        let status = metahumanStatus(meta)
        let accent = Color(hex: meta.accentHex)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(meta.name)
                            .font(ClayFonts.display(11, weight: .semibold))
                            .foregroundColor(accent)
                        Spacer()
                        Text(status.0)
                            .font(ClayFonts.display(9, weight: .semibold))
                            .foregroundColor(status.1)
                    }
                    Text(meta.description)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                    Text(meta.role)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.text)
                    MetahumanAffinityMeter(affinity: status.2, accent: accent)
                    if !meta.powers.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(meta.powers.prefix(3), id: \.self) { power in
                                MetahumanPowerTag(text: power, tint: accent)
                            }
                        }
                    }
                    if status.0 == "ALLY" {
                        Text(meta.allySummary)
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.text)
                    } else if status.0 == "ENEMY" {
                        Text(meta.enemySummary)
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.text)
                    } else {
                        Text("Encounter to learn more.")
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.text)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                        .fill(ClayTheme.panelElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                        .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                )
            }
        }
    }

    private func metahumanStatus(_ meta: MetahumanDefinition) -> (String, Color, Int) {
        if let state = engine.state.metahumans[meta.id] {
            switch state.disposition {
            case .ally:
                return ("ALLY", ClayTheme.good, state.affinity)
            case .enemy:
                return ("ENEMY", ClayTheme.bad, state.affinity)
            case .neutral:
                return ("NEUTRAL", ClayTheme.muted, state.affinity)
            }
        }
        return ("UNKNOWN", ClayTheme.muted, 0)
    }
}
