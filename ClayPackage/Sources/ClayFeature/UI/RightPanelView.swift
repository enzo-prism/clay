import SwiftUI

struct RightPanelView: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SoftCard(title: "Next Actions") {
                        GuidanceCenterView(maxItems: 4)
                    }
                    SoftCard(title: "Timers") {
                        VStack(alignment: .leading, spacing: 8) {
                            if engine.state.activeProjects.isEmpty && engine.state.dispatches.isEmpty {
                                Text("No active timers.")
                                    .font(ClayFonts.data(10))
                                    .foregroundColor(ClayTheme.muted)
                            } else {
                                if !engine.state.activeProjects.isEmpty {
                                    Text("Projects")
                                        .font(ClayFonts.display(9, weight: .semibold))
                                        .foregroundColor(ClayTheme.muted)
                                    ForEach(engine.state.activeProjects) { project in
                                        ActiveProjectRow(project: project)
                                    }
                                }
                                if !engine.state.dispatches.isEmpty {
                                    Text("Dispatches")
                                        .font(ClayFonts.display(9, weight: .semibold))
                                        .foregroundColor(ClayTheme.muted)
                                    ForEach(engine.state.dispatches) { dispatch in
                                        ActiveDispatchMiniRow(dispatch: dispatch)
                                    }
                                }
                            }
                        }
                    }
                    SoftCard(title: "Alerts") {
                        AlertsPanel()
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .accessibilityIdentifier("right_panel")
        .padding(12)
        .frame(width: 260)
        .background(
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        ClayTheme.panel.opacity(0.92),
                        ClayTheme.panelElevated.opacity(0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            Rectangle()
                .fill(ClayTheme.stroke.opacity(0.6))
                .frame(width: 1),
            alignment: .leading
        )
    }
}

private struct ActiveDispatchMiniRow: View {
    @EnvironmentObject private var engine: GameEngine
    let dispatch: DispatchInstance

    var body: some View {
        let definition = engine.content.dispatchesById[dispatch.dispatchId]
        let title = definition?.name ?? dispatch.dispatchId
        HStack(spacing: 8) {
            PixelSpriteView(spriteId: "dispatch", size: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Text(dispatch.status == .active ? dispatch.remainingSeconds.clayTimeString : "Ready")
                    .font(ClayFonts.data(9))
                    .foregroundColor(dispatch.status == .active ? ClayTheme.muted : ClayTheme.good)
                    .monospacedDigit()
                    .claySingleLine(minScale: 0.75)
            }
            Spacer(minLength: 0)
            if dispatch.status != .active {
                ClayButton(isEnabled: true, active: true) {
                    engine.collectDispatch(id: dispatch.id)
                } label: {
                    Text("Collect")
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

private struct AlertsPanel: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        let caps = engine.derived.resourceCaps
        let nearCap = engine.state.resources.filter { resource in
            let cap = caps[resource.key, default: 0]
            return cap > 0 && resource.value.amount >= cap * 0.9
        }
        let negativeRates = engine.derived.resourceRatesPerHour.filter { $0.value < 0 }
        let expiringContracts = engine.state.factionStates.values
            .flatMap(\.activeContracts)
            .filter { $0.remainingSeconds < 3600 }
        VStack(alignment: .leading, spacing: 6) {
            if nearCap.isEmpty && negativeRates.isEmpty && expiringContracts.isEmpty {
                Text("No alerts right now.")
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
            } else {
                if !nearCap.isEmpty {
                    AlertRow(title: "Storage Near Cap", detail: "\(nearCap.count) resources", tint: ClayTheme.accentWarm)
                }
                if !negativeRates.isEmpty {
                    AlertRow(title: "Negative Nets", detail: "\(negativeRates.count) resources", tint: ClayTheme.bad)
                }
                if !expiringContracts.isEmpty {
                    AlertRow(title: "Contracts Expiring", detail: "\(expiringContracts.count) within 1h", tint: ClayTheme.accent)
                }
            }
        }
    }
}

private struct AlertRow: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.text)
                Text(detail)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ActiveProjectRow: View {
    @EnvironmentObject private var engine: GameEngine
    let project: ProjectInstance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    
    var body: some View {
        let titleModel = timerTitleModel
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                PixelSpriteView(spriteId: titleModel.spriteId, size: 12)
                VStack(alignment: .leading, spacing: 1) {
                    if let kind = titleModel.kindLabel {
                        Text(kind.uppercased())
                            .font(ClayFonts.display(8, weight: .semibold))
                            .foregroundColor(ClayTheme.muted)
                            .claySingleLine(minScale: 0.7)
                    }
                    Text(titleModel.title)
                        .font(ClayFonts.display(11, weight: .semibold))
                        .clayTwoLines(minScale: 0.8)
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
            }
            SimpleProgressBar(value: progressValue, isActive: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(project.remainingSeconds.clayTimeString)
                    .monospacedDigit()
                    .claySingleLine(minScale: 0.75)
                actionButtons
            }
            .font(ClayFonts.data(10))
            .foregroundColor(ClayTheme.muted)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.accent.opacity(pulse ? 0.7 : 0.3), lineWidth: 1)
        )
        .onAppear {
            guard !reduceMotion else { return }
            pulse = false
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private struct TimerTitleModel {
        let title: String
        let kindLabel: String?
        let spriteId: String
    }

    private var timerTitleModel: TimerTitleModel {
        if let definition = engine.content.projectsById[project.projectId] {
            return TimerTitleModel(title: definition.name, kindLabel: nil, spriteId: "work")
        }

        if project.projectId.hasPrefix("build:") {
            let buildingId = String(project.projectId.dropFirst("build:".count))
            let buildingName = engine.content.buildingsById[buildingId]?.name ?? prettyTitle(from: buildingId)
            return TimerTitleModel(title: buildingName, kindLabel: "Build", spriteId: buildingId)
        }

        if project.projectId.hasPrefix("upgrade:") {
            let buildingId = String(project.projectId.dropFirst("upgrade:".count))
            let buildingName = engine.content.buildingsById[buildingId]?.name ?? prettyTitle(from: buildingId)
            return TimerTitleModel(title: buildingName, kindLabel: "Upgrade", spriteId: buildingId)
        }

        return TimerTitleModel(title: prettyTitle(from: project.projectId), kindLabel: nil, spriteId: "work")
    }

    private func prettyTitle(from raw: String) -> String {
        let cleaned = raw
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let parts = cleaned.split(separator: " ").map { String($0) }
        if parts.isEmpty { return raw }
        return parts.map { $0.capitalized }.joined(separator: " ")
    }
    
    private var progressValue: Double {
        guard project.totalSeconds > 0 else { return 1 }
        return max(0, min(1, 1 - (project.remainingSeconds / project.totalSeconds)))
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            let catalystBlock = engine.catalystBlockReason(projectId: project.id)
            let catalystEnabled = catalystBlock == nil
            ClayButton(isEnabled: catalystEnabled, blockedMessage: catalystBlock) {
                engine.activateCatalyst(for: project.id)
            } label: {
                Text("Catalyst")
            }
            let shardBlock = engine.shardBlockReason(projectId: project.id)
            let shardEnabled = shardBlock == nil
            ClayButton(isEnabled: shardEnabled, blockedMessage: shardBlock) {
                engine.useChronoShard(on: project.id)
            } label: {
                Text("Shard")
            }
        }
    }
}
