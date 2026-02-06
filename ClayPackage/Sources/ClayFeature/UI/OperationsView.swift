import SwiftUI

struct OperationsView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Operations", subtitle: "Dispatch crews on timed runs for extra rewards.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Panel(title: "Ready to Collect") {
                        let ready = engine.state.dispatches.filter { $0.status != .active }
                        if ready.isEmpty {
                            Text("No dispatches ready.")
                                .font(ClayFonts.data(10))
                                .foregroundColor(ClayTheme.muted)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(ready) { dispatch in
                                    ActiveDispatchRow(dispatch: dispatch)
                                }
                            }
                        }
                    }
                    Panel(title: "Active Dispatches") {
                        let active = engine.state.dispatches.filter { $0.status == .active }
                        if active.isEmpty {
                            Text("No active dispatches.")
                                .font(ClayFonts.data(10))
                                .foregroundColor(ClayTheme.muted)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(active) { dispatch in
                                    ActiveDispatchRow(dispatch: dispatch)
                                }
                            }
                        }
                    }
                    Panel(title: "Available Dispatches") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(availableDispatches(), id: \.id) { dispatch in
                                DispatchCard(dispatch: dispatch)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }

    private func availableDispatches() -> [DispatchDefinition] {
        let currentEra = engine.content.erasById[engine.state.eraId]?.sortOrder ?? 0
        return engine.content.pack.dispatches
            .filter { dispatch in
                let required = engine.content.erasById[dispatch.era]?.sortOrder ?? 0
                return currentEra >= required
            }
            .sorted { $0.durationSeconds < $1.durationSeconds }
    }
}

struct DispatchCard: View {
    @EnvironmentObject private var engine: GameEngine
    let dispatch: DispatchDefinition

    var body: some View {
        let blockReason = engine.dispatchBlockReason(dispatch)
        let isEnabled = blockReason == nil
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                PixelSpriteView(spriteId: spriteId(), size: 14)
                Text(dispatch.name)
                    .font(ClayFonts.display(11, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Spacer()
                Text("\(Int(dispatch.durationSeconds / 3600))h")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.7)
            }
            Text(dispatch.description)
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
                .clayTwoLines(minScale: 0.9)
            HStack {
                Text("Crew \(dispatch.requiredCrew)")
                Spacer()
                InlineStatusPill(text: "Risk \(Int(dispatch.riskChance * 100))%", tint: dispatch.riskChance > 0.25 ? ClayTheme.bad : ClayTheme.accentWarm)
            }
            .font(ClayFonts.data(9))
            HStack(spacing: 6) {
                ForEach(dispatch.rewards.keys.sorted(), id: \.self) { resourceId in
                    let amount = dispatch.rewards[resourceId, default: 0]
                    let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                    HStack(spacing: 4) {
                        ResourceIconView(resourceId: resourceId, size: 12, tint: tint)
                        Text("+\(amount.clayFormatted)")
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
                ClayButton(isEnabled: isEnabled, blockedMessage: blockReason) {
                    engine.startDispatch(dispatchId: dispatch.id)
                } label: {
                    Text("Start")
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

    private func spriteId() -> String {
        if dispatch.tags.contains("industry") { return "work" }
        if dispatch.tags.contains("science") { return "work" }
        if dispatch.tags.contains("diplomacy") { return "dispatch" }
        return "dispatch"
    }
}

struct ActiveDispatchRow: View {
    @EnvironmentObject private var engine: GameEngine
    let dispatch: DispatchInstance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        let definition = engine.content.dispatchesById[dispatch.dispatchId]
        let title = definition?.name ?? dispatch.dispatchId
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                PixelSpriteView(spriteId: "dispatch", size: 14)
                Text(title)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Spacer()
                statusLabel
            }
            if dispatch.status == .active {
                SimpleProgressBar(value: progressValue, isActive: true)
                Text(dispatch.remainingSeconds.clayTimeString)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .monospacedDigit()
                    .claySingleLine(minScale: 0.85)
            } else {
                Text(dispatch.status == .ready ? "Ready to collect" : "Recovery required")
                    .font(ClayFonts.data(9))
                    .foregroundColor(dispatch.status == .ready ? ClayTheme.good : ClayTheme.accentWarm)
                    .claySingleLine(minScale: 0.85)
            }
            if dispatch.status != .active {
                ClayButton(isEnabled: true, active: true) {
                    engine.collectDispatch(id: dispatch.id)
                } label: {
                    Text(dispatch.status == .ready ? "Collect" : "Recover")
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(dispatch.status == .active ? ClayTheme.accent.opacity(pulse ? 0.7 : 0.3) : ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
        .onAppear {
            guard dispatch.status == .active, !reduceMotion else { return }
            pulse = false
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var progressValue: Double {
        guard let def = engine.content.dispatchesById[dispatch.dispatchId] else { return 0 }
        let total = def.durationSeconds
        guard total > 0 else { return 1 }
        return max(0, min(1, 1 - (dispatch.remainingSeconds / total)))
    }

    private var statusLabel: some View {
        let text: String
        let color: Color
        switch dispatch.status {
        case .active:
            text = "IN PROGRESS"
            color = ClayTheme.muted
        case .ready:
            text = "READY"
            color = ClayTheme.good
        case .failed:
            text = "FAILED"
            color = ClayTheme.bad
        }
        return Text(text)
            .font(ClayFonts.display(8, weight: .semibold))
            .foregroundColor(color)
    }
}
