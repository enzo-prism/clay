import SwiftUI

struct BuildPaletteView: View {
    @EnvironmentObject private var engine: GameEngine
    @EnvironmentObject private var toastCenter: ToastCenter
    @Binding var selectedBuildId: String?
    let onCollapse: () -> Void
    @State private var hoveredId: String? = nil
    @State private var searchText: String = ""
    @State private var selectedCategory: String = "all"
    @State private var selectedSort: BuildSort = .impact

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BuildCatalogHeader(
                title: "BUILD",
                countText: "\(filteredIds.count)/\(unlockedIds.count)",
                searchText: $searchText,
                selectedSort: $selectedSort,
                onCollapse: onCollapse
            )
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    BuildCategoryChip(
                        title: "All",
                        isSelected: selectedCategory == "all",
                        color: ClayTheme.muted
                    ) {
                        selectedCategory = "all"
                    }
                    ForEach(categories, id: \.self) { category in
                        BuildCategoryChip(
                            title: BuildingCategoryStyle.label(for: category),
                            isSelected: selectedCategory == category,
                            color: BuildingCategoryStyle.color(for: category)
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            BuildDetailPanel(
                buildingId: detailId,
                selectedBuildId: selectedBuildId
            )

            BuildCatalogGrid(
                buildingIds: filteredIds,
                selectedBuildId: $selectedBuildId,
                hoveredId: $hoveredId
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ClayTheme.panelElevated.opacity(0.95), ClayTheme.panel.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.accent.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: ClayTheme.shadow, radius: 12, x: 0, y: 8)
        .animation(.easeInOut(duration: 0.15), value: hoveredId)
    }

    private var unlockedIds: [String] {
        engine.state.unlockedBuildingIds
    }

    private var filteredIds: [String] {
        sortBuildings(filteredBuildingIds(from: unlockedIds))
    }

    private var categories: [String] {
        categoryList(from: unlockedIds)
    }

    private var detailId: String? {
        hoveredId ?? selectedBuildId
    }

    private func filteredBuildingIds(from ids: [String]) -> [String] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = trimmed.lowercased()
        return ids.filter { id in
            guard let def = engine.content.buildingsById[id] else { return false }
            if selectedCategory != "all", def.category != selectedCategory {
                return false
            }
            guard !query.isEmpty else { return true }
            let nameMatch = def.name.lowercased().contains(query)
            let categoryMatch = def.category.lowercased().contains(query)
            let labelMatch = BuildingCategoryStyle.label(for: def.category).lowercased().contains(query)
            return nameMatch || categoryMatch || labelMatch
        }
    }

    private func categoryList(from ids: [String]) -> [String] {
        let categories = ids.compactMap { id in
            engine.content.buildingsById[id]?.category
        }
        let unique = Array(Set(categories))
        return unique.sorted { BuildingCategoryStyle.label(for: $0) < BuildingCategoryStyle.label(for: $1) }
    }

    private func sortBuildings(_ ids: [String]) -> [String] {
        let definitions = ids.compactMap { id in
            engine.content.buildingsById[id].map { (id: id, def: $0) }
        }
        switch selectedSort {
        case .cost:
            return definitions.sorted { lhs, rhs in
                totalCost(lhs.def) < totalCost(rhs.def)
            }.map(\.id)
        case .time:
            return definitions.sorted { lhs, rhs in
                lhs.def.buildTimeSeconds < rhs.def.buildTimeSeconds
            }.map(\.id)
        case .impact:
            return definitions.sorted { lhs, rhs in
                impactScore(lhs.def) > impactScore(rhs.def)
            }.map(\.id)
        }
    }

    private func totalCost(_ def: BuildingDefinition) -> Double {
        def.baseCost.values.reduce(0, +)
    }

    private func impactScore(_ def: BuildingDefinition) -> Double {
        let production = def.productionPerHour.values.reduce(0, +)
        let storage = def.storageCapAdd.values.reduce(0, +) * 0.2
        let defense = def.defenseScore * 0.6
        let logistics = def.logisticsCapAdd * 0.4
        let projectSpeed = def.projectSpeedBonus * 100
        return production + storage + defense + logistics + projectSpeed
    }
}

private struct BuildCatalogGrid: View {
    @EnvironmentObject private var engine: GameEngine
    @EnvironmentObject private var toastCenter: ToastCenter
    let buildingIds: [String]
    @Binding var selectedBuildId: String?
    @Binding var hoveredId: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(
                rows: [
                    GridItem(.fixed(BuildCardLayout.height), spacing: BuildCardLayout.gridSpacing),
                    GridItem(.fixed(BuildCardLayout.height), spacing: BuildCardLayout.gridSpacing)
                ],
                spacing: BuildCardLayout.gridSpacing
            ) {
                ForEach(buildingIds, id: \.self) { buildingId in
                    BuildCatalogCard(
                        buildingId: buildingId,
                        selectedBuildId: $selectedBuildId,
                        hoveredId: $hoveredId
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    private struct BuildCatalogCard: View {
        @EnvironmentObject private var engine: GameEngine
        @EnvironmentObject private var toastCenter: ToastCenter
        let buildingId: String
        @Binding var selectedBuildId: String?
        @Binding var hoveredId: String?

        var body: some View {
            if let def = engine.content.buildingsById[buildingId] {
                let blockReason = engine.buildBlockReason(buildingId: buildingId)
                let recommendation = recommendationReason(for: def)
                BuildCardView(
                    buildingId: buildingId,
                    def: def,
                    isSelected: selectedBuildId == buildingId,
                    isHovered: hoveredId == buildingId,
                    blockReason: blockReason,
                    benefitLines: Array(buildBenefitLines(for: def, content: engine.content).prefix(2)),
                    recommendation: recommendation
                ) {
                    if let blockReason {
                        toastCenter.push(message: blockReason, style: .warning)
                    } else {
                        selectedBuildId = buildingId
                    }
                }
                .onHover { hovering in
                    if hovering {
                        hoveredId = buildingId
                    } else if hoveredId == buildingId {
                        hoveredId = nil
                    }
                }
            }
        }

        private func recommendationReason(for def: BuildingDefinition) -> String? {
            if engine.derived.logistics.logisticsFactor < 0.85, def.logisticsCapAdd > 0 {
                return "Logistics"
            }
            if engine.derived.risk.raidChancePerHour > 0.12, def.defenseScore > 0 {
                return "Defense"
            }
            let caps = engine.derived.resourceCaps
            if engine.state.resources.contains(where: { resource in
                let cap = caps[resource.key, default: 0]
                return cap > 0 && resource.value.amount >= cap * 0.9
            }), !def.storageCapAdd.isEmpty {
                return "Storage"
            }
            if let worst = engine.derived.resourceRatesPerHour.min(by: { $0.value < $1.value }), worst.value < 0 {
                if def.productionPerHour[worst.key, default: 0] > 0 {
                    return "Fix \(worst.key.capitalized)"
                }
            }
            return nil
        }
    }
}

private struct BuildCatalogHeader: View {
    let title: String
    let countText: String
    @Binding var searchText: String
    @Binding var selectedSort: BuildSort
    let onCollapse: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(ClayFonts.display(12, weight: .bold))
                .foregroundColor(ClayTheme.text)
                .claySingleLine(minScale: 0.85)
            Text(countText)
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.85)
            Spacer()
            SegmentedControl(
                segments: BuildSort.allCases,
                selection: $selectedSort,
                activeTint: ClayTheme.accentWarm
            ) { sort, isSelected in
                Text(sort.label.uppercased())
                    .font(ClayFonts.display(8, weight: .semibold))
                    .foregroundColor(isSelected ? ClayTheme.accentText : ClayTheme.muted)
                    .claySingleLine(minScale: 0.7)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
            }
            BuildSearchField(text: $searchText)
            Button(action: onCollapse) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(ClayTheme.muted)
                    .frame(width: 26, height: 26)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Collapse build palette")
            .accessibilityIdentifier("build_palette_collapse")
        }
    }
}

private struct BuildSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            TextField("Search buildings", text: $text)
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.text)
                .textFieldStyle(.plain)
                .frame(minWidth: 160)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(ClayTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }
}

private struct BuildCategoryChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(ClayFonts.display(8, weight: .semibold))
                .foregroundColor(isSelected ? ClayTheme.accentText : color)
                .claySingleLine(minScale: 0.7)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? color : ClayTheme.panelElevated.opacity(hovering ? 0.9 : 0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? color.opacity(0.9) : ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct BuildDetailPanel: View {
    @EnvironmentObject private var engine: GameEngine
    let buildingId: String?
    let selectedBuildId: String?

    var body: some View {
        Group {
            if let buildingId,
               let def = engine.content.buildingsById[buildingId] {
                let lines = buildBenefitLines(for: def, content: engine.content)
                let blockReason = engine.buildBlockReason(buildingId: buildingId)
                let recommendation = recommendationReason(for: def)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 10) {
                        BuildPreviewView(buildingId: buildingId, category: def.category, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def.name)
                                .font(ClayFonts.display(11, weight: .semibold))
                                .foregroundColor(ClayTheme.text)
                            Text(BuildingCategoryStyle.label(for: def.category).uppercased())
                                .font(ClayFonts.data(8))
                                .foregroundColor(BuildingCategoryStyle.color(for: def.category))
                            if let recommendation {
                                InlineStatusPill(text: "Recommended: \(recommendation)", tint: ClayTheme.accentWarm)
                            }
                        }
                        Spacer()
                        BuildStatusPill(
                            text: blockReason ?? "Ready",
                            tint: blockReason == nil ? ClayTheme.good : ClayTheme.bad
                        )
                    }
                    HStack(spacing: 10) {
                        Text("Build \(def.buildTimeSeconds.clayTimeString)")
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.muted)
                        if selectedBuildId == buildingId {
                            Text("Click a tile to place.")
                                .font(ClayFonts.data(9))
                                .foregroundColor(ClayTheme.accent)
                        }
                    }
                    if !def.baseCost.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(def.baseCost.keys.sorted(), id: \.self) { resourceId in
                                let amount = def.baseCost[resourceId, default: 0]
                                let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                                BuildCostPill(resourceId: resourceId, amount: amount, tint: tint)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(lines.prefix(4), id: \.self) { line in
                            Text(line)
                                .font(ClayFonts.data(9))
                                .foregroundColor(ClayTheme.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .allowsTightening(true)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Text("Hover or select a building to preview.")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                    Spacer()
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }

    private func recommendationReason(for def: BuildingDefinition) -> String? {
        if engine.derived.logistics.logisticsFactor < 0.85, def.logisticsCapAdd > 0 {
            return "Logistics"
        }
        if engine.derived.risk.raidChancePerHour > 0.12, def.defenseScore > 0 {
            return "Defense"
        }
        let caps = engine.derived.resourceCaps
        if engine.state.resources.contains(where: { resource in
            let cap = caps[resource.key, default: 0]
            return cap > 0 && resource.value.amount >= cap * 0.9
        }), !def.storageCapAdd.isEmpty {
            return "Storage"
        }
        if let worst = engine.derived.resourceRatesPerHour.min(by: { $0.value < $1.value }), worst.value < 0 {
            if def.productionPerHour[worst.key, default: 0] > 0 {
                return "Fix \(worst.key.capitalized)"
            }
        }
        return nil
    }
}

private struct BuildCardView: View {
    @EnvironmentObject private var engine: GameEngine
    let buildingId: String
    let def: BuildingDefinition
    let isSelected: Bool
    let isHovered: Bool
    let blockReason: String?
    let benefitLines: [String]
    let recommendation: String?
    let onSelect: () -> Void

    var body: some View {
        let isBlocked = blockReason != nil
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    BuildPreviewView(buildingId: buildingId, category: def.category, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(def.name)
                            .font(ClayFonts.display(10, weight: .semibold))
                            .foregroundColor(ClayTheme.text)
                            .claySingleLine(minScale: 0.75)
                        Text(BuildingCategoryStyle.label(for: def.category).uppercased())
                            .font(ClayFonts.data(8))
                            .foregroundColor(BuildingCategoryStyle.color(for: def.category))
                            .claySingleLine(minScale: 0.75)
                    }
                    Spacer(minLength: 0)
                    if recommendation != nil {
                        InlineStatusPill(text: "Recommended", tint: ClayTheme.accentWarm)
                    }
                    BuildStatusPill(
                        text: blockReason ?? "Ready",
                        tint: blockReason == nil ? ClayTheme.good : ClayTheme.bad
                    )
                }
                Text("Build \(def.buildTimeSeconds.clayTimeString)")
                    .font(ClayFonts.data(8))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.8)
                if !def.baseCost.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(def.baseCost.keys.sorted(), id: \.self) { resourceId in
                            let amount = def.baseCost[resourceId, default: 0]
                            let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                            BuildCostPill(resourceId: resourceId, amount: amount, tint: tint)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(benefitLines.prefix(2), id: \.self) { line in
                        Text(line)
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .allowsTightening(true)
                    }
                }
            }
            .padding(10)
            .frame(width: BuildCardLayout.width, height: BuildCardLayout.height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ClayTheme.panelElevated.opacity(0.95), ClayTheme.panel.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .stroke(borderColor(isBlocked: isBlocked), lineWidth: 1)
            )
            .opacity(isBlocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private func borderColor(isBlocked: Bool) -> Color {
        if isSelected {
            return ClayTheme.accent.opacity(0.9)
        }
        if isHovered {
            return ClayTheme.accent.opacity(0.5)
        }
        if isBlocked {
            return ClayTheme.bad.opacity(0.5)
        }
        return ClayTheme.stroke.opacity(0.6)
    }
}

private enum BuildCardLayout {
    static let width: CGFloat = 220
    static let height: CGFloat = 116
    static let gridSpacing: CGFloat = 8
}

private enum BuildSort: String, CaseIterable, Hashable {
    case cost
    case time
    case impact

    var label: String {
        switch self {
        case .cost: return "Cost"
        case .time: return "Time"
        case .impact: return "Impact"
        }
    }
}

private struct BuildPreviewView: View {
    let buildingId: String
    let category: String
    let size: CGFloat

    var body: some View {
        if PixelAssetCatalog.shared.sprite(for: buildingId) != nil {
            PixelSpriteView(spriteId: buildingId, size: size, tint: nil, isActive: true, bobAmplitude: 0)
        } else if let detail = BuildingDetailImageCatalog.shared.image(for: buildingId) {
            Image(nsImage: detail)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let fallback = PixelBuildingDetailFallback.shared.image(for: buildingId) {
            Image(nsImage: fallback)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
        } else if let asset = KenneyAssetCatalog.shared.buildingAsset(for: buildingId) {
            ModelPreview(asset: asset)
                .frame(width: size, height: size)
        } else {
            BuildingIconView(buildingId: buildingId, category: category, size: size, tint: ClayTheme.accent)
        }
    }
}

private struct BuildStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(ClayFonts.data(7, weight: .semibold))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .allowsTightening(true)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ClayTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tint.opacity(0.6), lineWidth: 1)
            )
    }
}

private struct BuildCostPill: View {
    let resourceId: String
    let amount: Double
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            ResourceIconView(resourceId: resourceId, size: 9, tint: tint)
            Text(amount.clayFormatted)
                .font(ClayFonts.data(7, weight: .semibold))
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

private func buildBenefitLines(for def: BuildingDefinition, content: ContentCatalog) -> [String] {
    var lines: [String] = []
    if !def.productionPerHour.isEmpty {
        lines.append("Produces \(buildResourceList(def.productionPerHour, content: content, sign: "+", perHour: true))")
    }
    if !def.consumptionPerHour.isEmpty {
        lines.append("Consumes \(buildResourceList(def.consumptionPerHour, content: content, sign: "-", perHour: true))")
    }
    if !def.storageCapAdd.isEmpty {
        lines.append("Storage \(buildResourceList(def.storageCapAdd, content: content, sign: "+", perHour: false))")
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
        let name = content.buildingsById[adjacency.requiresBuildingId]?.name ?? adjacency.requiresBuildingId.capitalized
        lines.append("Adjacency: +\(percent)% near \(name)")
    }
    if !def.maintenancePerHour.isEmpty {
        lines.append("Upkeep \(buildResourceList(def.maintenancePerHour, content: content, sign: "-", perHour: true))")
    }
    if lines.isEmpty {
        lines.append("No direct bonuses.")
    }
    return lines
}

private func buildResourceList(_ amounts: ResourceAmount, content: ContentCatalog, sign: String, perHour: Bool) -> String {
    let parts = amounts.keys.sorted().compactMap { resourceId -> String? in
        let amount = amounts[resourceId, default: 0]
        guard amount != 0 else { return nil }
        let name = content.resourcesById[resourceId]?.name ?? resourceId.capitalized
        let suffix = perHour ? "/h" : ""
        return "\(sign)\(amount.clayFormatted) \(name)\(suffix)"
    }
    return parts.joined(separator: ", ")
}
