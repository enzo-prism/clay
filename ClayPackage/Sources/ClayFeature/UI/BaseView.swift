import SwiftUI

struct BaseView: View {
    @EnvironmentObject private var engine: GameEngine
    @State private var selectedBuildId: String? = nil
    @State private var selectedBuilding: BuildingInstance? = nil
    @State private var overlayMode: BaseOverlayMode = .none
    @State private var centerTrigger: Int = 0
    
    var body: some View {
        ZStack {
            BaseSceneView(selectedBuildId: $selectedBuildId, selectedBuilding: $selectedBuilding, overlayMode: $overlayMode, centerTrigger: $centerTrigger)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ClayMetrics.radius))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            VStack(spacing: 10) {
                baseHudBar()
                if let message = engine.projectAdvisorMessage() {
                    HintBanner(message: message, tone: .info)
                        .padding(.horizontal, 12)
                }
                Spacer()
                BuildPaletteView(selectedBuildId: $selectedBuildId)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            if let building = selectedBuilding, let def = engine.content.buildingsById[building.buildingId] {
                BaseInspectorCard(
                    building: building,
                    def: def,
                    preview: engine.upgradePreview(for: building),
                    purposeLines: purposeLines(for: def),
                    strategyLines: strategyLines(for: def),
                    upgradeLines: engine.upgradePreview(for: building).map { upgradeEffectLines($0) } ?? []
                )
                    .frame(maxWidth: 320)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onAppear { centerTrigger += 1 }
        .onChange(of: engine.state.gridSize) { _ in
            centerTrigger += 1
        }
    }

    @ViewBuilder
    private func baseHudBar() -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("BASE")
                    .font(ClayFonts.display(12, weight: .bold))
                Text(selectedBuilding == nil ? "Explore and build." : "Focused view active.")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
            }
            Spacer()
            HStack(spacing: 6) {
                OverlayButton(title: "None", mode: .none, selection: $overlayMode)
                OverlayButton(title: "Log", mode: .logistics, selection: $overlayMode)
                OverlayButton(title: "Dist", mode: .district, selection: $overlayMode)
                OverlayButton(title: "Risk", mode: .risk, selection: $overlayMode)
            }
            ClayButton(isEnabled: true, active: true) {
                centerTrigger += 1
            } label: {
                Text("Center")
            }
            ClayButton(isEnabled: true, active: true) {
                if selectedBuildId == nil {
                    selectedBuildId = engine.state.unlockedBuildingIds.first
                } else {
                    selectedBuildId = nil
                }
            } label: {
                Text(selectedBuildId == nil ? "Build" : "Cancel Build")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panel.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }

    private func purposeLines(for def: BuildingDefinition) -> [String] {
        var lines: [String] = []
        if !def.productionPerHour.isEmpty {
            lines.append("Produces \(resourceList(def.productionPerHour, perHour: true)).")
        }
        if !def.consumptionPerHour.isEmpty {
            lines.append("Consumes \(resourceList(def.consumptionPerHour, perHour: true)).")
        }
        if !def.storageCapAdd.isEmpty {
            lines.append("Increases storage for \(resourceList(def.storageCapAdd, perHour: false)).")
        }
        if def.defenseScore > 0 {
            lines.append("Improves security and reduces raid risk.")
        }
        if def.projectSpeedBonus > 0 {
            let percent = Int(def.projectSpeedBonus * 100)
            lines.append("Speeds projects by \(percent)%.")
        }
        if def.logisticsCapAdd > 0 {
            lines.append("Raises logistics capacity to keep production efficient.")
        }
        if lines.isEmpty {
            lines.append("Provides infrastructure support.")
        }
        return lines
    }

    private func strategyLines(for def: BuildingDefinition) -> [String] {
        var lines: [String] = []
        if !def.productionPerHour.isEmpty {
            lines.append("Build early to grow net output and upgrade when caps rise.")
        }
        if !def.storageCapAdd.isEmpty {
            lines.append("Add before you hit caps so production is not wasted.")
        }
        if def.defenseScore > 0 {
            lines.append("Stack with security pacts for near-zero raid risk.")
        }
        if def.logisticsCapAdd > 0 {
            lines.append("Use when logistics factor starts dropping below 1.0.")
        }
        if let adjacency = def.adjacencyBonus {
            let name = engine.content.buildingsById[adjacency.requiresBuildingId]?.name ?? adjacency.requiresBuildingId.capitalized
            lines.append("Place adjacent to \(name) to gain the bonus.")
        }
        if let tag = def.districtTag, def.districtBonus > 1 {
            lines.append("Cluster with other \(tag) buildings for the district bonus.")
        }
        if !def.maintenancePerHour.isEmpty {
            lines.append("Maintain steady \(resourceList(def.maintenancePerHour, perHour: true)) to avoid slowdown.")
        }
        if lines.isEmpty {
            lines.append("No special setup required.")
        }
        return lines
    }

    private func resourceList(_ amounts: ResourceAmount, perHour: Bool) -> String {
        let parts = amounts.keys.sorted().compactMap { resourceId -> String? in
            let amount = amounts[resourceId, default: 0]
            guard amount != 0 else { return nil }
            let name = engine.content.resourcesById[resourceId]?.name ?? resourceId.capitalized
            let suffix = perHour ? "/h" : ""
            return "\(amount.clayFormatted) \(name)\(suffix)"
        }
        return parts.joined(separator: ", ")
    }

    private func upgradeEffectLines(_ preview: UpgradePreview) -> [String] {
        var lines: [String] = []
        if !preview.deltaProductionPerHour.isEmpty {
            lines.append("Output: \(deltaResourceList(preview.deltaProductionPerHour, perHour: true))")
        }
        if !preview.deltaConsumptionPerHour.isEmpty {
            lines.append("Input: \(deltaResourceList(preview.deltaConsumptionPerHour, perHour: true))")
        }
        if !preview.deltaStorageCap.isEmpty {
            lines.append("Storage: \(deltaResourceList(preview.deltaStorageCap, perHour: false))")
        }
        if preview.deltaLogisticsCap > 0 {
            lines.append("Logistics cap +\(preview.deltaLogisticsCap.clayFormatted)")
        }
        if preview.deltaProjectSpeed > 0 {
            let percent = Int(preview.deltaProjectSpeed * 100)
            lines.append("Project speed +\(percent)%")
        }
        if preview.deltaDefense > 0 {
            lines.append("Defense +\(preview.deltaDefense.clayFormatted)")
        }
        if lines.isEmpty {
            lines.append("No measurable output change.")
        }
        return lines
    }

    private func deltaResourceList(_ amounts: ResourceAmount, perHour: Bool) -> String {
        let parts = amounts.keys.sorted().compactMap { resourceId -> String? in
            let amount = amounts[resourceId, default: 0]
            guard abs(amount) > 0.0001 else { return nil }
            let name = engine.content.resourcesById[resourceId]?.name ?? resourceId.capitalized
            let suffix = perHour ? "/h" : ""
            let sign = amount >= 0 ? "+" : ""
            return "\(sign)\(amount.clayFormatted) \(name)\(suffix)"
        }
        return parts.joined(separator: ", ")
    }
}

private struct BaseInspectorCard: View {
    @EnvironmentObject private var engine: GameEngine
    let building: BuildingInstance
    let def: BuildingDefinition
    let preview: UpgradePreview?
    let purposeLines: [String]
    let strategyLines: [String]
    let upgradeLines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(def.name.uppercased())
                .font(ClayFonts.display(11, weight: .bold))
                .foregroundColor(ClayTheme.accent)
            if PixelAssetCatalog.shared.sprite(for: building.buildingId) != nil {
                PixelSpriteView(spriteId: building.buildingId, size: 140, tint: nil, isActive: true, bobAmplitude: 0)
                    .padding(.vertical, 4)
            } else if let detail = BuildingDetailImageCatalog.shared.image(for: building.buildingId) {
                Image(nsImage: detail)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 140)
                    .padding(.vertical, 4)
            } else if let fallback = PixelBuildingDetailFallback.shared.image(for: building.buildingId) {
                Image(nsImage: fallback)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 120)
                    .padding(.vertical, 4)
            } else if let asset = KenneyAssetCatalog.shared.buildingAsset(for: building.buildingId) {
                ModelPreview(asset: asset)
            } else {
                BuildingIconView(buildingId: building.buildingId, category: def.category, size: 46, tint: ClayTheme.accent)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Purpose")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                ForEach(purposeLines, id: \.self) { line in
                    Text("- \(line)")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.text)
                }
                Text("Best Use")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                    .padding(.top, 4)
                ForEach(strategyLines, id: \.self) { line in
                    Text("- \(line)")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.text)
                }
            }
            if let preview {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Upgrade Preview")
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(ClayTheme.accent)
                    HStack(spacing: 8) {
                        Text("Cost")
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.muted)
                        ForEach(preview.cost.keys.sorted(), id: \.self) { resourceId in
                            let amount = preview.cost[resourceId, default: 0]
                            let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                            HStack(spacing: 4) {
                                ResourceIconView(resourceId: resourceId, size: 9, tint: tint)
                                Text(amount.clayFormatted)
                                    .font(ClayFonts.data(8, weight: .semibold))
                                    .foregroundColor(ClayTheme.text)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(ClayTheme.panelElevated.opacity(0.9))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                            )
                        }
                    }
                    HStack(spacing: 8) {
                        Text("Duration")
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.muted)
                        Text(preview.durationSeconds.clayTimeString)
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.text)
                    }
                    ForEach(upgradeLines, id: \.self) { line in
                        Text(line)
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.text)
                    }
                }
            }
            HStack {
                Spacer()
                let blockReason = engine.upgradeBlockReason(building)
                ClayButton(isEnabled: blockReason == nil, blockedMessage: blockReason) {
                    engine.upgradeBuilding(building)
                } label: {
                    Text("Upgrade")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

struct BaseGridView: View {
    @EnvironmentObject private var engine: GameEngine
    @Binding var selectedBuildId: String?
    @Binding var selectedBuilding: BuildingInstance?
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @GestureState private var dragOffset: CGSize = .zero
    
    var body: some View {
        let cellSize: CGFloat = 26
        let gridSize = engine.state.gridSize
        let columns = Array(repeating: GridItem(.fixed(cellSize), spacing: 2), count: gridSize)
        ScrollView([.vertical, .horizontal]) {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<(gridSize * gridSize), id: \.self) { index in
                    let x = index % gridSize
                    let y = index / gridSize
                    BaseCellView(x: x, y: y, selectedBuildId: $selectedBuildId, selectedBuilding: $selectedBuilding)
                        .frame(width: cellSize, height: cellSize)
                }
            }
            .scaleEffect(scale)
            .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(2.0, max(0.6, value))
                    }
            )
            .padding()
        }
    }
}

struct BaseCellView: View {
    @EnvironmentObject private var engine: GameEngine
    @EnvironmentObject private var toastCenter: ToastCenter
    let x: Int
    let y: Int
    @Binding var selectedBuildId: String?
    @Binding var selectedBuilding: BuildingInstance?
    
    var body: some View {
        let building = engine.buildingAt(x: x, y: y)
        ZStack {
            Rectangle()
                .fill(ClayTheme.panelElevated)
                .overlay(
                    Rectangle()
                        .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 0.5)
                )
            if let building = building,
               let def = engine.content.buildingsById[building.buildingId] {
                Rectangle()
                    .fill(color(for: def.category))
                    .opacity(0.8)
                BuildingIconView(buildingId: building.buildingId, category: def.category, size: 12, tint: ClayTheme.text)
            } else if selectedBuildId != nil {
                Rectangle()
                    .fill(ClayTheme.accent.opacity(0.15))
                    .opacity(0.4)
            }
        }
        .onTapGesture {
            if let building = building {
                selectedBuilding = building
            } else if let selected = selectedBuildId {
                if engine.gridOccupied(x: x, y: y) {
                    toastCenter.push(message: "Tile occupied", style: .warning)
                    return
                }
                if let reason = engine.buildBlockReason(buildingId: selected) {
                    toastCenter.push(message: reason, style: .warning)
                    return
                }
                engine.startBuilding(buildingId: selected, at: (x, y))
                selectedBuildId = nil
            }
        }
    }
    
    private func color(for category: String) -> Color {
        switch category {
        case "collector": return Color(hex: "#3A7CA5")
        case "storage": return Color(hex: "#66796B")
        case "defense": return Color(hex: "#A63D40")
        case "institution": return Color(hex: "#7C6BA6")
        case "energy": return Color(hex: "#F2C14E")
        case "economy": return Color(hex: "#5AA9E6")
        case "accelerator": return Color(hex: "#4ECDC4")
        default: return Color(hex: "#324B5C")
        }
    }
}

struct BuildPaletteView: View {
    @EnvironmentObject private var engine: GameEngine
    @Binding var selectedBuildId: String?
    @State private var hoveredId: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let def = hoveredId.flatMap({ engine.content.buildingsById[$0] }) {
                BenefitPopover(title: def.name, lines: benefitLines(for: def))
                    .transition(.opacity)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(engine.state.unlockedBuildingIds, id: \.self) { buildingId in
                        if let def = engine.content.buildingsById[buildingId] {
                            let isHovered = hoveredId == buildingId
                            Button {
                                selectedBuildId = buildingId
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        if PixelAssetCatalog.shared.sprite(for: buildingId) != nil {
                                            PixelSpriteView(spriteId: buildingId, size: 14, tint: nil, isActive: true, bobAmplitude: 0)
                                        } else {
                                            BuildingIconView(buildingId: buildingId, category: def.category, size: 14, tint: ClayTheme.text)
                                        }
                                        Text(def.name)
                                    }
                                    .font(ClayFonts.display(10, weight: .semibold))
                                    Text("Build \(def.buildTimeSeconds.clayTimeString)")
                                        .font(ClayFonts.data(9))
                                        .foregroundColor(ClayTheme.muted)
                                    if !def.baseCost.isEmpty {
                                        HStack(spacing: 6) {
                                            ForEach(def.baseCost.keys.sorted(), id: \.self) { resourceId in
                                                let amount = def.baseCost[resourceId, default: 0]
                                                let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                                                HStack(spacing: 4) {
                                                    ResourceIconView(resourceId: resourceId, size: 10, tint: tint)
                                                    Text(amount.clayFormatted)
                                                        .font(ClayFonts.data(8, weight: .semibold))
                                                        .foregroundColor(ClayTheme.text)
                                                }
                                                .padding(.vertical, 2)
                                                .padding(.horizontal, 4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .fill(ClayTheme.panelElevated.opacity(0.9))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                        .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                                                )
                                            }
                                        }
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .allowsTightening(true)
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                                        .fill(selectedBuildId == buildingId ? ClayTheme.panelElevated : (isHovered ? ClayTheme.panelElevated.opacity(0.7) : ClayTheme.panel))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                                        .stroke(selectedBuildId == buildingId ? ClayTheme.accent.opacity(0.6) : (isHovered ? ClayTheme.stroke.opacity(0.9) : ClayTheme.stroke.opacity(0.6)), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .help(benefitLines(for: def).joined(separator: "\n"))
                            .onHover { hovering in
                                if hovering {
                                    hoveredId = buildingId
                                } else if hoveredId == buildingId {
                                    hoveredId = nil
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: hoveredId)
    }

    private func benefitLines(for def: BuildingDefinition) -> [String] {
        var lines: [String] = []
        if !def.productionPerHour.isEmpty {
            lines.append("Produces \(resourceList(def.productionPerHour, sign: "+", perHour: true))")
        }
        if !def.consumptionPerHour.isEmpty {
            lines.append("Consumes \(resourceList(def.consumptionPerHour, sign: "-", perHour: true))")
        }
        if !def.storageCapAdd.isEmpty {
            lines.append("Storage \(resourceList(def.storageCapAdd, sign: "+", perHour: false))")
        }
        if def.defenseScore > 0 {
            lines.append("Defense +\(def.defenseScore.clayFormatted)")
        }
        if def.projectSpeedBonus > 0 {
            let percent = Int(def.projectSpeedBonus * 100)
            lines.append("Project speed +\(percent)%")
        }
        if def.logisticsCapAdd > 0 {
            lines.append("Logistics cap +\(def.logisticsCapAdd.clayFormatted)")
        }
        if let tag = def.districtTag, def.districtBonus > 1 {
            let percent = Int((def.districtBonus - 1) * 100)
            lines.append("District \(tag.capitalized) +\(percent)%")
        }
        if let adjacency = def.adjacencyBonus {
            let percent = Int((adjacency.multiplier - 1) * 100)
            let name = engine.content.buildingsById[adjacency.requiresBuildingId]?.name ?? adjacency.requiresBuildingId.capitalized
            lines.append("Adjacency: +\(percent)% near \(name)")
        }
        if !def.maintenancePerHour.isEmpty {
            lines.append("Upkeep \(resourceList(def.maintenancePerHour, sign: "-", perHour: true))")
        }
        if lines.isEmpty {
            lines.append("No direct bonuses.")
        }
        return lines
    }

    private func resourceList(_ amounts: ResourceAmount, sign: String, perHour: Bool) -> String {
        let parts = amounts.keys.sorted().compactMap { resourceId -> String? in
            let amount = amounts[resourceId, default: 0]
            guard amount != 0 else { return nil }
            let name = engine.content.resourcesById[resourceId]?.name ?? resourceId.capitalized
            let suffix = perHour ? "/h" : ""
            return "\(sign)\(amount.clayFormatted) \(name)\(suffix)"
        }
        return parts.joined(separator: ", ")
    }
}

private struct BenefitPopover: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.text)
            }
        }
        .padding(10)
        .frame(maxWidth: 240, alignment: .leading)
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

struct OverlayButton: View {
    let title: String
    let mode: BaseOverlayMode
    @Binding var selection: BaseOverlayMode
    
    var body: some View {
        ClayButton(isEnabled: true, active: selection == mode) {
            selection = mode
        } label: {
            Text(title)
        }
    }
}
