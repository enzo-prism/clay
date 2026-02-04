import SwiftUI

struct RightPanelView: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Panel(title: "Work Crews") {
                    HStack(spacing: 8) {
                        PixelSpriteView(spriteId: "worker", size: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Available")
                                .font(ClayFonts.data(10))
                                .foregroundColor(ClayTheme.muted)
                            Text("\(engine.derived.availableCrewCount) / \(engine.state.crewCount)")
                                .font(ClayFonts.data(13, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)
                        }
                        Spacer(minLength: 0)
                    }
                }
                Panel(title: "Active Projects") {
                    if engine.state.activeProjects.isEmpty {
                        Text("No active projects.")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(engine.state.activeProjects) { project in
                                ActiveProjectRow(project: project)
                            }
                        }
                    }
                }
                Panel(title: "Accelerators") {
                    RightPanelRow(label: "Catalyst", value: Date() >= engine.state.catalyst.availableAt ? "Ready" : "Cooldown", valueColor: Date() >= engine.state.catalyst.availableAt ? ClayTheme.good : ClayTheme.accentWarm)
                    RightPanelRow(label: "Chrono Shards", value: "\(engine.state.chronoShards)")
                }
            }
            .padding(.vertical, 4)
        }
        .padding(12)
        .frame(width: 260)
        .background(ClayTheme.panel)
        .overlay(
            Rectangle()
                .fill(ClayTheme.stroke.opacity(0.6))
                .frame(width: 1),
            alignment: .leading
        )
    }
}

private struct RightPanelRow: View {
    let label: String
    let value: String
    var valueColor: Color = ClayTheme.text

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(ClayFonts.data(11))
                .foregroundColor(ClayTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
            Spacer(minLength: 0)
            Text(value)
                .font(ClayFonts.data(11, weight: .semibold))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
    }
}

struct ActiveProjectRow: View {
    @EnvironmentObject private var engine: GameEngine
    let project: ProjectInstance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    
    var body: some View {
        let definition = engine.content.projectsById[project.projectId]
        let title = definition?.name ?? project.projectId
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                PixelSpriteView(spriteId: "work", size: 12)
                Text(title)
                    .font(ClayFonts.display(11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                Spacer(minLength: 0)
            }
            SimpleProgressBar(value: progressValue, isActive: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(project.remainingSeconds.clayTimeString)
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
