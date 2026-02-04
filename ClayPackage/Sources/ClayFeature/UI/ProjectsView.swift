import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var engine: GameEngine
    @State private var activeFilters: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Projects", subtitle: "Invest in long-term upgrades and unlock new eras.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let message = engine.projectAdvisorMessage() {
                        HintBanner(message: message, tone: .info)
                    }
                    AutoPlannerPanel(activeFilters: $activeFilters)
                    FilterBar(activeFilters: $activeFilters)
                    if !engine.state.queuedProjects.isEmpty {
                        QueuedProjectsPanel()
                    }
                    ForEach(availableProjects(), id: \.id) { project in
                        ProjectCard(project: project)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func availableProjects() -> [ProjectDefinition] {
        let unlocked = Set(engine.state.unlockedProjectIds)
        let completed = Set(engine.state.completedProjectIds)
        let filtered = engine.content.pack.projects
            .filter { unlocked.contains($0.id) && !completed.contains($0.id) }
        let active = activeFilters
        let byTag = active.isEmpty ? filtered : filtered.filter { !active.isDisjoint(with: Set($0.tags)) }
        return byTag.sorted { $0.durationSeconds < $1.durationSeconds }
    }
}

struct AutoPlannerPanel: View {
    @EnvironmentObject private var engine: GameEngine
    @Binding var activeFilters: Set<String>
    
    private let tags = ["economy", "science", "defense", "era", "accelerator", "infrastructure"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Planner".uppercased())
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                Spacer()
                SimpleToggle(label: "", isOn: Binding(get: { engine.state.autoPlanRules.enabled }, set: { engine.setAutoPlannerEnabled($0) }))
            }
            Text("Auto-queue one affordable project per free crew using preferred tags.")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    let enabled = engine.state.autoPlanRules.priorityTags.contains(tag)
                    ClayButton(isEnabled: true, active: enabled) {
                        engine.setAutoPlanTag(tag, enabled: !enabled)
                    } label: {
                        Text(tag.capitalized)
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

struct FilterBar: View {
    @Binding var activeFilters: Set<String>
    private let filters = ["economy", "science", "defense", "era", "accelerator"]
    
    var body: some View {
        HStack(spacing: 6) {
            ClayButton(isEnabled: true, active: activeFilters.isEmpty) {
                activeFilters.removeAll()
            } label: {
                Text("All")
            }
            ForEach(filters, id: \.self) { filter in
                let enabled = activeFilters.contains(filter)
                ClayButton(isEnabled: true, active: enabled) {
                    if enabled {
                        activeFilters.remove(filter)
                    } else {
                        activeFilters.insert(filter)
                    }
                } label: {
                    Text(filter.capitalized)
                }
            }
        }
    }
}

struct ProjectCard: View {
    @EnvironmentObject private var engine: GameEngine
    let project: ProjectDefinition
    
    var body: some View {
        let blockReason = engine.projectBlockReason(project)
        let isEnabled = blockReason == nil
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                PixelSpriteView(spriteId: spriteId(), size: 14)
                Text(project.name)
                    .font(ClayFonts.display(12, weight: .semibold))
                Spacer()
                Text(project.category.uppercased())
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.muted)
            }
            Text(project.description)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
            if !impactTags().isEmpty {
                ImpactRow(tags: impactTags())
            }
            if !domainImpact().isEmpty {
                DomainImpactRow(domains: domainImpact())
            }
            HStack {
                Text("Duration \(project.durationSeconds.clayTimeString)")
                Spacer()
                Text("Crew \(project.crewRequired)")
            }
            .font(ClayFonts.data(10))
            HStack {
                ForEach(project.costs.keys.sorted(), id: \.self) { key in
                    let amount = project.costs[key, default: 0]
                    let tint = engine.content.resourcesById[key].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                    HStack(spacing: 6) {
                        ResourceIconView(resourceId: key, size: 12, tint: tint)
                        Text("\(key.capitalized): \(amount.clayFormatted)")
                            .font(ClayFonts.data(9))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                            .fill(ClayTheme.panelElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                            .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
                }
                Spacer()
                let queueReason = engine.projectQueueBlockReason(project)
                let queueEnabled = queueReason == nil
                ClayButton(isEnabled: queueEnabled, blockedMessage: queueReason) {
                    engine.queueProject(projectId: project.id, source: .research)
                } label: {
                    Text(engine.state.queuedProjects.contains(where: { $0.projectId == project.id }) ? "Queued" : "Queue")
                }
                ClayButton(isEnabled: isEnabled, blockedMessage: blockReason) {
                    engine.startProject(projectId: project.id, source: .research)
                } label: {
                    Text("Start")
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }

    private func spriteId() -> String {
        if project.tags.contains("diplomacy") { return "dispatch" }
        if project.tags.contains("science") { return "work" }
        if project.tags.contains("institution") { return "work" }
        return "work"
    }
    
    private func impactTags() -> [ImpactTag] {
        var tags: [ImpactTag] = []
        for effect in project.effects {
            switch effect.type {
            case "add_resource_cap":
                if let resourceId = effect.resourceId, let amount = effect.amount {
                    let name = engine.content.resourcesById[resourceId]?.name ?? resourceId.capitalized
                    tags.append(ImpactTag(text: "Cap +\(amount.clayFormatted) \(name)", color: ClayTheme.accent))
                }
            case "add_resource_multiplier":
                if let resourceId = effect.resourceId, let multiplier = effect.multiplier {
                    let name = engine.content.resourcesById[resourceId]?.name ?? resourceId.capitalized
                    let percent = Int((multiplier - 1) * 100)
                    tags.append(ImpactTag(text: "+\(percent)% \(name)", color: ClayTheme.good))
                }
            case "add_global_multiplier":
                if let multiplier = effect.multiplier {
                    let percent = Int((multiplier - 1) * 100)
                    tags.append(ImpactTag(text: "+\(percent)% Global", color: ClayTheme.good))
                }
            case "add_crew":
                if let count = effect.crewCount {
                    tags.append(ImpactTag(text: "+\(count) Crew", color: ClayTheme.accent))
                }
            case "project_speed_bonus":
                if let amount = effect.amount {
                    let percent = Int(amount * 100)
                    tags.append(ImpactTag(text: "+\(percent)% Speed", color: ClayTheme.accentWarm))
                }
            case "add_security_bonus":
                if let amount = effect.amount {
                    tags.append(ImpactTag(text: "+\(amount.clayFormatted) Security", color: ClayTheme.accentWarm))
                }
            case "add_logistics_cap":
                if let amount = effect.amount {
                    tags.append(ImpactTag(text: "+\(amount.clayFormatted) Logistics", color: ClayTheme.accent))
                }
            case "grant_resource":
                if let resourceId = effect.resourceId, let amount = effect.amount {
                    let name = engine.content.resourcesById[resourceId]?.name ?? resourceId.capitalized
                    tags.append(ImpactTag(text: "+\(amount.clayFormatted) \(name)", color: ClayTheme.accent))
                }
            case "unlock_building":
                if let buildingId = effect.buildingId,
                   let name = engine.content.buildingsById[buildingId]?.name {
                    tags.append(ImpactTag(text: "Unlock \(name)", color: ClayTheme.muted))
                }
            case "unlock_project":
                if let projectId = effect.projectId,
                   let name = engine.content.projectsById[projectId]?.name {
                    tags.append(ImpactTag(text: "Unlock \(name)", color: ClayTheme.muted))
                }
            case "unlock_contract":
                if let contractId = effect.contractId,
                   let name = engine.content.contractsById[contractId]?.name {
                    tags.append(ImpactTag(text: "Unlock \(name)", color: ClayTheme.muted))
                }
            case "unlock_era":
                if let eraId = effect.eraId,
                   let name = engine.content.erasById[eraId]?.name {
                    tags.append(ImpactTag(text: "Era: \(name)", color: ClayTheme.muted))
                }
            default:
                break
            }
        }
        if tags.count > 3 {
            let extra = tags.count - 3
            tags = Array(tags.prefix(3))
            tags.append(ImpactTag(text: "+\(extra) more", color: ClayTheme.muted))
        }
        return tags
    }

    private func domainImpact() -> [DomainDefinition] {
        let tagSet = Set(project.tags)
        return engine.content.pack.domains.filter { !tagSet.isDisjoint(with: Set($0.tags)) }
    }
}

struct ImpactTag: Identifiable {
    let id = UUID()
    let text: String
    let color: Color
}

struct DomainImpactRow: View {
    let domains: [DomainDefinition]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(domains) { domain in
                HStack(spacing: 4) {
                    KenneyIconView(path: domain.iconPath, size: 10, tint: ClayTheme.accent)
                    Text("\(domain.name) +1")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                        .fill(ClayTheme.panelElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                        .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                )
            }
            Spacer()
        }
    }
}

struct ImpactRow: View {
    let tags: [ImpactTag]
    
    var body: some View {
        HStack(spacing: 6) {
            Text("Impact")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            ForEach(tags) { tag in
                Text(tag.text)
                    .font(ClayFonts.data(9))
                    .foregroundColor(tag.color)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ClayTheme.panelElevated)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
            }
            Spacer()
        }
    }
}

struct QueuedProjectsPanel: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        Panel(title: "Queued Projects") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(engine.state.queuedProjects) { queued in
                    if let def = engine.content.projectsById[queued.projectId] {
                        HStack {
                            Text(def.name)
                                .font(ClayFonts.display(10, weight: .semibold))
                            Spacer()
                            ClayButton(isEnabled: true, active: false) {
                                engine.unqueueProject(id: queued.id)
                            } label: {
                                Text("Remove")
                            }
                        }
                        .font(ClayFonts.data(9))
                    }
                }
            }
        }
    }
}
