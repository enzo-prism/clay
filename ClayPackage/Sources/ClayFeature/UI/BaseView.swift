import SwiftUI

struct BaseView: View {
    @Binding var isBaseFocusMode: Bool
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedBuildId: String? = nil
    @State private var selectedBuilding: BuildingInstance? = nil
    @State private var overlayMode: BaseOverlayMode = .none
    @State private var centerTrigger: Int = 0
    @State private var isBuildPaletteCollapsed: Bool = false
    /// When `true`, the inspector stays visible even with no selection.
    /// When `false`, it behaves like a contextual inspector that only shows while something is selected.
    @State private var inspectorPinned: Bool = false
    @State private var inspectorHidden: Bool = false
    
    var body: some View {
        GeometryReader { proxy in
            let dockInspector = proxy.size.width >= 980
            Group {
                if dockInspector {
                    HStack(alignment: .top, spacing: 12) {
                        baseSceneStack()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        if shouldShowInspector {
                            inspectorPanel()
                                .frame(width: 360)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        baseSceneStack()
                        if shouldShowInspector {
                            inspectorPanel()
                                .frame(width: min(360, proxy.size.width - 24))
                                .padding(.top, 72)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(12)
        }
        .onAppear { centerTrigger += 1 }
        .onExitCommand {
            if isBaseFocusMode {
                setBaseFocusMode(false)
                return
            }
            if selectedBuildId != nil {
                selectedBuildId = nil
                return
            }
            if selectedBuilding != nil {
                selectedBuilding = nil
                return
            }
            if shouldShowInspector {
                hideInspector()
            }
        }
        .onChange(of: selectedBuildId) { newValue in
            if newValue != nil {
                selectedBuilding = nil
                if !isBaseFocusMode {
                    isBuildPaletteCollapsed = true
                }
            }
        }
        .onChange(of: selectedBuilding?.id) { newId in
            if newId != nil {
                selectedBuildId = nil
            }
        }
        .onChange(of: engine.state.gridSize) { _ in
            centerTrigger += 1
        }
    }

    private var shouldShowInspector: Bool {
        !isBaseFocusMode && !inspectorHidden && (inspectorPinned || selectedBuildId != nil || selectedBuilding != nil)
    }

    private func hideInspector() {
        inspectorPinned = false
        inspectorHidden = true
    }

    private func setBaseFocusMode(_ isEnabled: Bool) {
        if reduceMotion {
            isBaseFocusMode = isEnabled
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                isBaseFocusMode = isEnabled
            }
        }
    }

    private func collapseBuildPalette() {
        if reduceMotion {
            isBuildPaletteCollapsed = true
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                isBuildPaletteCollapsed = true
            }
        }
    }

    private func expandBuildPalette() {
        if reduceMotion {
            isBuildPaletteCollapsed = false
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                isBuildPaletteCollapsed = false
            }
        }
    }

    @ViewBuilder
    private func baseSceneStack() -> some View {
        ZStack {
            BaseSceneView(selectedBuildId: $selectedBuildId, selectedBuilding: $selectedBuilding, overlayMode: $overlayMode, centerTrigger: $centerTrigger)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: ClayMetrics.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
	                        .stroke(ClayTheme.stroke.opacity(0.55), lineWidth: 1)
	                )

                if isBaseFocusMode {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            focusControlsBar()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 10) {
                        baseHudBar()
                        if let message = engine.projectAdvisorMessage() {
                            HintBanner(message: message, tone: .info)
                                .padding(.horizontal, 12)
                        }
                        Spacer(minLength: 0)
                        if isBuildPaletteCollapsed {
                            HStack(spacing: 10) {
                                buildPaletteCollapsedHandle()
                                Spacer(minLength: 0)
                            }
                        } else {
                            BuildPaletteView(selectedBuildId: $selectedBuildId, onCollapse: collapseBuildPalette)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
	        }
	    }

	    private func inspectorPanel() -> some View {
	        BaseDockPanel(
	            selectedBuildId: selectedBuildId,
	            selectedBuilding: selectedBuilding,
	            onClose: hideInspector
	        )
	    }

    @ViewBuilder
    private func baseHudBar() -> some View {
        VStack(spacing: 6) {
            ViewThatFits(in: .horizontal) {
                baseHudWideLayout()
                baseHudCompactLayout()
            }
            if !reduceMotion {
                ViewThatFits(in: .horizontal) {
                    overlayLegend()
                    EmptyView()
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ClayTheme.panelElevated.opacity(0.98), ClayTheme.panel.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.55), lineWidth: 1)
        )
    }

    private func baseTitleBlock() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("BASE")
                .font(ClayFonts.display(12, weight: .bold))
            Text(selectedBuilding == nil ? "Explore and build." : "Focused view active.")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
        }
    }

    private func centerButton() -> some View {
        ClayButton(isEnabled: true, active: true) {
            centerTrigger += 1
        } label: {
            HStack(spacing: 6) {
                KenneyIconView(path: "KenneySelected/Icons/icon_target.png", size: 12, tint: ClayTheme.accentText)
                Text("Center")
            }
        }
        .help("Center the base view")
    }

	    private func baseHudWideLayout() -> some View {
	        HStack(spacing: 10) {
	            baseTitleBlock()
	            Spacer(minLength: 12)
            buildModeStatus()
                .layoutPriority(1)
            Spacer(minLength: 12)
	            overlayControls()
	                .layoutPriority(1)
	            centerButton()
	            inspectorToggle()
                focusToggle()
	        }
	    }

	    private func baseHudCompactLayout() -> some View {
	        VStack(spacing: 8) {
	            HStack(spacing: 10) {
	                baseTitleBlock()
	                Spacer(minLength: 12)
	                centerButton()
	                inspectorToggle()
                    focusToggle()
	            }
	            HStack(spacing: 10) {
	                buildModeStatus()
	                    .frame(maxWidth: 320, alignment: .leading)
                    .layoutPriority(1)
                Spacer(minLength: 12)
                overlayControls()
                    .layoutPriority(2)
            }
        }
    }

	    private func inspectorToggle() -> some View {
	        ClayButton(isEnabled: true, active: shouldShowInspector) {
	            if shouldShowInspector {
	                hideInspector()
	            } else {
                    inspectorHidden = false
                    if selectedBuildId == nil && selectedBuilding == nil {
                        inspectorPinned = true
                    }
	            }
	        } label: {
	            HStack(spacing: 6) {
	                KenneyIconView(path: "KenneySelected/Icons/icon_menu.png", size: 12, tint: shouldShowInspector ? ClayTheme.accentText : ClayTheme.muted)
	                Text(shouldShowInspector ? "Hide" : "Inspect")
            }
	        }
	        .help("Toggle Build/Inspect panel")
	    }

    private func focusToggle() -> some View {
        ClayButton(isEnabled: true, active: true) {
            setBaseFocusMode(true)
        } label: {
            HStack(spacing: 6) {
                KenneyIconView(path: "KenneySelected/Icons/icon_target.png", size: 12, tint: ClayTheme.accentText)
                Text("Focus")
            }
        }
        .help("Hide side panels for a focused base view")
        .accessibilityIdentifier("base_focus_toggle")
    }

    private func buildPaletteCollapsedHandle() -> some View {
        ClayButton(isEnabled: true, active: true) {
            expandBuildPalette()
        } label: {
            HStack(spacing: 6) {
                KenneyIconView(path: "KenneySelected/Icons/icon_wrench.png", size: 12, tint: ClayTheme.accentText)
                Text("Build")
            }
        }
        .help("Expand build palette")
        .accessibilityIdentifier("build_palette_expand")
    }

    private func focusControlsBar() -> some View {
        HStack(spacing: 8) {
            ClayButton(isEnabled: true, active: true) {
                setBaseFocusMode(false)
            } label: {
                HStack(spacing: 6) {
                    KenneyIconView(path: "KenneySelected/Icons/icon_home.png", size: 12, tint: ClayTheme.accentText)
                    Text("Exit Focus")
                }
            }
            .accessibilityIdentifier("base_focus_exit")

            ClayButton(isEnabled: true, active: true) {
                centerTrigger += 1
            } label: {
                HStack(spacing: 6) {
                    KenneyIconView(path: "KenneySelected/Icons/icon_target.png", size: 12, tint: ClayTheme.accentText)
                    Text("Center")
                }
            }

            ClayButton(isEnabled: true, active: true) {
                setBaseFocusMode(false)
                inspectorHidden = false
                inspectorPinned = true
            } label: {
                HStack(spacing: 6) {
                    KenneyIconView(path: "KenneySelected/Icons/icon_menu.png", size: 12, tint: ClayTheme.accentText)
                    Text("Inspect")
                }
            }

            ClayButton(isEnabled: true, active: true) {
                setBaseFocusMode(false)
                expandBuildPalette()
            } label: {
                HStack(spacing: 6) {
                    KenneyIconView(path: "KenneySelected/Icons/icon_wrench.png", size: 12, tint: ClayTheme.accentText)
                    Text("Build")
                }
            }

            if selectedBuildId != nil {
                ClayButton(isEnabled: true, active: true) {
                    selectedBuildId = nil
                } label: {
                    Text("Cancel")
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ClayTheme.panelElevated.opacity(0.98), ClayTheme.panel.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.55), lineWidth: 1)
        )
    }
	
	    private func overlayControls() -> some View {
	        HStack(spacing: 8) {
	            SegmentedControl(segments: overlaySegments, selection: $overlayMode) { mode, isSelected in
	                HStack(spacing: 6) {
                    KenneyIconView(
                        path: overlayIcon(for: mode),
                        size: 12,
                        tint: isSelected ? ClayTheme.accentText : overlayTint(for: mode)
                    )
                    Text(overlayTitle(for: mode).uppercased())
                        .font(ClayFonts.display(9, weight: .semibold))
                        .foregroundColor(isSelected ? ClayTheme.accentText : ClayTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .allowsTightening(true)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }
            let logisticsFactor = engine.derived.logistics.logisticsFactor
            let raidChance = engine.derived.risk.raidChancePerHour
            HStack(spacing: 6) {
                HUDStatChip(
                    title: "Logistics",
                    value: "x\(formatFactor(logisticsFactor))",
                    tint: logisticsTint(logisticsFactor),
                    iconPath: "KenneySelected/Icons/icon_bars.png"
                )
                HUDStatChip(
                    title: "Raid / h",
                    value: "\(Int(raidChance * 100))%",
                    tint: raidTint(raidChance),
                    iconPath: "KenneySelected/Icons/icon_target.png"
                )
            }
        }
    }

    private func overlayLegend() -> some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)
            Text("Logistics = capacity vs demand")
                .font(ClayFonts.data(8))
                .foregroundColor(ClayTheme.muted)
            Text("Defense = security contribution")
                .font(ClayFonts.data(8))
                .foregroundColor(ClayTheme.muted)
        }
        .padding(.top, -2)
    }

    private var overlaySegments: [BaseOverlayMode] {
        [.none, .logisticsImpact, .district, .defense]
    }

    private func overlayTitle(for mode: BaseOverlayMode) -> String {
        switch mode {
        case .none: return "None"
        case .logisticsImpact: return "Logistics"
        case .district: return "District"
        case .defense: return "Defense"
        }
    }

    private func overlayIcon(for mode: BaseOverlayMode) -> String {
        switch mode {
        case .none: return "KenneySelected/Icons/icon_menu.png"
        case .logisticsImpact: return "KenneySelected/Icons/icon_bars.png"
        case .district: return "KenneySelected/Icons/icon_gear.png"
        case .defense: return "KenneySelected/Icons/icon_target.png"
        }
    }

    private func overlayTint(for mode: BaseOverlayMode) -> Color {
        switch mode {
        case .none: return ClayTheme.muted
        case .logisticsImpact: return ClayTheme.good
        case .district: return ClayTheme.accent
        case .defense: return ClayTheme.accentWarm
        }
    }

    private func formatFactor(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func logisticsTint(_ value: Double) -> Color {
        if value >= 0.95 { return ClayTheme.good }
        if value >= 0.8 { return ClayTheme.accentWarm }
        return ClayTheme.bad
    }

    private func raidTint(_ value: Double) -> Color {
        if value >= 0.18 { return ClayTheme.bad }
        if value >= 0.08 { return ClayTheme.accentWarm }
        return ClayTheme.good
    }

    @ViewBuilder
    private func buildModeStatus() -> some View {
        if let buildId = selectedBuildId,
           let def = engine.content.buildingsById[buildId] {
            HStack(spacing: 6) {
                buildModePill(text: "Placing: \(def.name)", tint: ClayTheme.accent)
                ClayButton(isEnabled: true, active: false) {
                    selectedBuildId = nil
                } label: {
                    Text("Cancel")
                }
            }
        } else {
            buildModePill(text: "Select a building below, then click a tile to place.", tint: ClayTheme.muted)
        }
    }

    private func buildModePill(text: String, tint: Color) -> some View {
        Text(text)
            .font(ClayFonts.data(9))
            .foregroundColor(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .allowsTightening(true)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .fill(ClayTheme.panelElevated.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .stroke(tint.opacity(0.6), lineWidth: 1)
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
        if def.cohesionPerHour != 0 {
            let sign = def.cohesionPerHour > 0 ? "+" : ""
            lines.append("Cohesion \(sign)\(def.cohesionPerHour.clayFormatted)/h.")
        }
        if def.biospherePerHour != 0 {
            let sign = def.biospherePerHour > 0 ? "+" : ""
            lines.append("Biosphere \(sign)\(def.biospherePerHour.clayFormatted)/h.")
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

private struct BaseDockPanel: View {
    @EnvironmentObject private var engine: GameEngine
    let selectedBuildId: String?
    let selectedBuilding: BuildingInstance?
    let onClose: () -> Void

    var body: some View {
        SoftCard {
            HStack(alignment: .center, spacing: 10) {
                Text("Build / Inspect".uppercased())
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.8)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ClayTheme.muted.opacity(0.85))
                        .accessibilityLabel("Close inspector")
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let building = selectedBuilding, let def = engine.content.buildingsById[building.buildingId] {
                        BaseInspectorCard(
                            building: building,
                            def: def,
                            preview: engine.upgradePreview(for: building),
                            purposeLines: purposeLines(for: def),
                            strategyLines: strategyLines(for: def),
                            upgradeLines: engine.upgradePreview(for: building).map { upgradeEffectLines($0) } ?? [],
                            isEmbedded: true
                        )
                    } else if let buildId = selectedBuildId, let def = engine.content.buildingsById[buildId] {
                        BuildSelectionCard(def: def)
                    } else {
                        EmptyState(title: "Select a Building", subtitle: "Choose a build or click a structure to inspect.")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
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
        if def.cohesionPerHour != 0 {
            let sign = def.cohesionPerHour > 0 ? "+" : ""
            lines.append("Cohesion \(sign)\(def.cohesionPerHour.clayFormatted)/h.")
        }
        if def.biospherePerHour != 0 {
            let sign = def.biospherePerHour > 0 ? "+" : ""
            lines.append("Biosphere \(sign)\(def.biospherePerHour.clayFormatted)/h.")
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

private struct BuildSelectionCard: View {
    @EnvironmentObject private var engine: GameEngine
    let def: BuildingDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                BaseBuildPreviewView(buildingId: def.id, category: def.category, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(def.name)
                        .font(ClayFonts.display(11, weight: .semibold))
                    Text("Tap a tile to place")
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                }
                Spacer(minLength: 0)
            }
            if !def.baseCost.isEmpty {
                HStack(spacing: 6) {
                    ForEach(def.baseCost.keys.sorted(), id: \.self) { resourceId in
                        let amount = def.baseCost[resourceId, default: 0]
                        let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                        BaseBuildCostPill(resourceId: resourceId, amount: amount, tint: tint)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(baseBenefitLines(for: def, content: engine.content).prefix(3), id: \.self) { line in
                    Text(line)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.text)
                }
            }
        }
    }
}

private struct BaseBuildPreviewView: View {
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

private struct BaseBuildCostPill: View {
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

private func baseBenefitLines(for def: BuildingDefinition, content: ContentCatalog) -> [String] {
    var lines: [String] = []
    if !def.productionPerHour.isEmpty {
        lines.append("Produces \(baseResourceList(def.productionPerHour, content: content, sign: "+", perHour: true))")
    }
    if !def.consumptionPerHour.isEmpty {
        lines.append("Consumes \(baseResourceList(def.consumptionPerHour, content: content, sign: "-", perHour: true))")
    }
    if !def.storageCapAdd.isEmpty {
        lines.append("Storage \(baseResourceList(def.storageCapAdd, content: content, sign: "+", perHour: false))")
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
        lines.append("Upkeep \(baseResourceList(def.maintenancePerHour, content: content, sign: "-", perHour: true))")
    }
    if lines.isEmpty {
        lines.append("No direct bonuses.")
    }
    return lines
}

private func baseResourceList(_ amounts: ResourceAmount, content: ContentCatalog, sign: String, perHour: Bool) -> String {
    let parts = amounts.keys.sorted().compactMap { resourceId -> String? in
        let amount = amounts[resourceId, default: 0]
        guard amount != 0 else { return nil }
        let name = content.resourcesById[resourceId]?.name ?? resourceId.capitalized
        let suffix = perHour ? "/h" : ""
        return "\(sign)\(amount.clayFormatted) \(name)\(suffix)"
    }
    return parts.joined(separator: ", ")
}

private struct BaseInspectorCard: View {
    @EnvironmentObject private var engine: GameEngine
    let building: BuildingInstance
    let def: BuildingDefinition
    let preview: UpgradePreview?
    let purposeLines: [String]
    let strategyLines: [String]
    let upgradeLines: [String]
    var isEmbedded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(def.name.uppercased())
                .font(ClayFonts.display(11, weight: .bold))
                .foregroundColor(ClayTheme.accent)
                .claySingleLine(minScale: 0.75)
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
                        .claySingleLine(minScale: 0.8)
                    HStack(spacing: 8) {
                        Text("Cost")
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.muted)
                            .claySingleLine(minScale: 0.8)
                        ForEach(preview.cost.keys.sorted(), id: \.self) { resourceId in
                            let amount = preview.cost[resourceId, default: 0]
                            let tint = engine.content.resourcesById[resourceId].map { Color(hex: $0.colorHex) } ?? ClayTheme.accent
                            HStack(spacing: 4) {
                                ResourceIconView(resourceId: resourceId, size: 9, tint: tint)
                                Text(amount.clayFormatted)
                                    .font(ClayFonts.data(8, weight: .semibold))
                                    .foregroundColor(ClayTheme.text)
                                    .monospacedDigit()
                                    .claySingleLine(minScale: 0.75)
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
                            .claySingleLine(minScale: 0.8)
                        Text(preview.durationSeconds.clayTimeString)
                            .font(ClayFonts.data(8))
                            .foregroundColor(ClayTheme.text)
                            .monospacedDigit()
                            .claySingleLine(minScale: 0.75)
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
            Group {
                if !isEmbedded {
                    RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                        .fill(ClayTheme.panel)
                } else {
                    Color.clear
                }
            }
        )
        .overlay(
            Group {
                if !isEmbedded {
                    RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                        .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                }
            }
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
                    .fill(BuildingCategoryStyle.color(for: def.category))
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
}
