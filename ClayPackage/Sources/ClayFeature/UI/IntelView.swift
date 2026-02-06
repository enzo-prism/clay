import SwiftUI

struct IntelView: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.eraTheme) private var eraTheme
    @State private var activeCategories: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Intel", subtitle: "Monitor risk, events, and system health.") {
                ClayButton(isEnabled: true) {
                    engine.debugTriggerMetahumanEncounter()
                } label: {
                    Text("Force Metahuman")
                }
            }
            IntelAlertBanner()
            HStack(spacing: 12) {
                RiskCard(title: "Exposure", value: engine.derived.risk.exposure, accent: eraTheme.accentWarm)
                RiskCard(title: "Security", value: engine.derived.risk.security, accent: eraTheme.good)
                RiskCard(title: "Hostility", value: engine.derived.risk.hostility, accent: eraTheme.bad)
                RiskCard(title: "Raid / h", value: engine.derived.risk.raidChancePerHour, accent: eraTheme.accent)
            }
            .padding(.horizontal, 12)
            HStack(spacing: 12) {
                MetricCard(title: "Efficiency", value: engine.derived.averageEfficiency, accent: eraTheme.accent)
                MetricCard(title: "Logistics", value: engine.derived.logistics.logisticsFactor, accent: eraTheme.good)
                MetricCard(title: "Market", value: marketIndex(), accent: eraTheme.accentWarm)
            }
            .padding(.horizontal, 12)
            HStack(spacing: 12) {
                MetricCard(
                    title: "Cohesion",
                    value: engine.state.cohesion,
                    accent: ClayTheme.good,
                    displayValue: "\(Int(engine.state.cohesion * 100))%"
                )
                MetricCard(
                    title: "Biosphere",
                    value: engine.state.biosphere,
                    accent: ClayTheme.accentWarm,
                    displayValue: "\(Int(engine.state.biosphere * 100))%"
                )
            }
            .padding(.horizontal, 12)
            ResourceForecastPanel()
                .padding(.horizontal, 12)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    IntelCategoryFilter(activeCategories: $activeCategories)
                    ForEach(filteredEvents()) { event in
                        IntelEventCard(event: event)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }

    private func marketIndex() -> Double {
        let index = engine.derived.marketIndexByResource["credits", default: 1.0]
        return min(1.0, max(0.0, (index - 0.6) / 0.8))
    }

    private func metahumanFor(chain: EventChainDefinition) -> MetahumanDefinition? {
        guard chain.id.hasPrefix("meta_") else { return nil }
        let id = chain.id.replacingOccurrences(of: "meta_", with: "")
        return engine.content.metahumansById[id]
    }

    private func filteredEvents() -> [EventLogEntry] {
        guard !activeCategories.isEmpty else { return engine.state.events }
        return engine.state.events.filter { activeCategories.contains($0.category) }
    }
}

private struct IntelAlertBanner: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        if let pendingId = engine.state.eventChains.pendingEventChainId,
           let chain = engine.content.eventChainsById[pendingId] {
            if let meta = metahumanFor(chain: chain) {
                MetahumanDecisionPanel(chain: chain, metahuman: meta)
                    .padding(.horizontal, 12)
            } else {
                DecisionPanel(chain: chain)
                    .padding(.horizontal, 12)
            }
        } else {
            GuidanceBanner(
                title: "All Clear",
                message: "No decisions pending. Keep an eye on risk and market shifts.",
                priorityColor: ClayTheme.good,
                actionTitle: nil,
                action: nil
            )
            .padding(.horizontal, 12)
        }
    }

    private func metahumanFor(chain: EventChainDefinition) -> MetahumanDefinition? {
        guard chain.id.hasPrefix("meta_") else { return nil }
        let id = chain.id.replacingOccurrences(of: "meta_", with: "")
        return engine.content.metahumansById[id]
    }
}

private struct IntelCategoryFilter: View {
    @Binding var activeCategories: Set<String>
    private let categories = ["raid", "market", "decision", "construction", "project", "era", "domain", "system", "contract", "dispatch"]

    var body: some View {
        HStack(spacing: 6) {
            ClayButton(isEnabled: true, active: activeCategories.isEmpty) {
                activeCategories.removeAll()
            } label: {
                Text("All")
            }
            ForEach(categories, id: \.self) { category in
                let enabled = activeCategories.contains(category)
                ClayButton(isEnabled: true, active: enabled) {
                    if enabled {
                        activeCategories.remove(category)
                    } else {
                        activeCategories.insert(category)
                    }
                } label: {
                    Text(category.capitalized)
                }
            }
        }
    }
}

private struct IntelEventCard: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.eraTheme) private var eraTheme
    let event: EventLogEntry

    var body: some View {
        let accent = eventAccent(for: event.category)
        HStack(alignment: .top, spacing: 10) {
            eventIcon(for: event.category)
                .frame(width: 18, height: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.title)
                        .font(ClayFonts.display(11, weight: .semibold))
                    EventCategoryBadge(text: event.category, tint: accent)
                    Spacer()
                    Text(event.timestamp, style: .time)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                }
                Text(event.message)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
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
        .overlay(
            Rectangle()
                .fill(accent.opacity(0.7))
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous)),
            alignment: .leading
        )
    }

    private func eventIcon(for category: String) -> some View {
        if let iconDef = PixelAssetCatalog.shared.eventIcon(for: category),
           let image = PixelAssetCatalog.shared.iconImage(for: iconDef) {
            return AnyView(PixelIconView(image: image, size: 18, tint: nil))
        }
        return AnyView(KenneyIconView(path: "KenneySelected/Icons/icon_info.png", size: 18, tint: ClayTheme.accent))
    }

    private func eventAccent(for category: String) -> Color {
        switch category {
        case "raid": return eraTheme.bad
        case "market": return eraTheme.accentWarm
        case "decision": return eraTheme.accent
        case "construction", "project": return eraTheme.accent
        case "era": return eraTheme.good
        case "domain": return eraTheme.accentWarm
        case "system": return eraTheme.muted
        case "contract", "diplomacy": return eraTheme.accent
        case "dispatch": return eraTheme.good
        default: return eraTheme.accent
        }
    }
}

private struct EventCategoryBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(ClayFonts.display(8, weight: .semibold))
            .foregroundColor(tint)
            .claySingleLine(minScale: 0.6)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tint.opacity(0.35), lineWidth: 1)
            )
    }
}

struct ResourceForecastPanel: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        Panel(title: "Resource Forecasts") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(engine.content.pack.resources.sorted(by: { $0.sortOrder < $1.sortOrder })) { resource in
                    ResourceForecastRow(resourceId: resource.id)
                }
                Divider()
                BottleneckRow(bottlenecks: topBottlenecks())
            }
        }
    }
    
    private func topBottlenecks() -> [String] {
        let rates = engine.derived.resourceRatesPerHour
        return rates.sorted { $0.value < $1.value }
            .prefix(3)
            .map { $0.key }
    }
}

struct ResourceForecastRow: View {
    @EnvironmentObject private var engine: GameEngine
    let resourceId: String
    
    var body: some View {
        let def = engine.content.resourcesById[resourceId]
        let name = def?.name ?? resourceId.capitalized
        let amount = engine.state.resources[resourceId]?.amount ?? 0
        let cap = engine.derived.resourceCaps[resourceId, default: 0]
        let rate = engine.derived.resourceRatesPerHour[resourceId, default: 0]
        let status = statusText(amount: amount, cap: cap, rate: rate)
        let statusColor = statusColor(rate: rate, amount: amount, cap: cap)
        HStack {
            ResourceIconView(resourceId: resourceId, size: 12, tint: Color(hex: def?.colorHex ?? "#8EC5FF"))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Text("\(formattedRate(rate))/h • \(amount.clayFormatted)/\(cap.clayFormatted)")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.75)
            }
            Spacer()
            Text(status)
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(statusColor)
                .claySingleLine(minScale: 0.75)
        }
    }
    
    private func formattedRate(_ rate: Double) -> String {
        let sign = rate >= 0 ? "+" : ""
        return "\(sign)\(rate.clayFormatted)"
    }
    
    private func statusText(amount: Double, cap: Double, rate: Double) -> String {
        if cap > 0, amount >= cap * 0.98 {
            return "At cap"
        }
        if rate < 0 {
            let hours = amount / max(0.1, abs(rate))
            return "Empty in \(TimeInterval(hours * 3600).clayTimeString)"
        }
        let timeToCap = engine.derived.timeToCapHours[resourceId] ?? nil
        if let hours = timeToCap {
            return "Cap in \(TimeInterval(hours * 3600).clayTimeString)"
        }
        return "Stable"
    }
    
    private func statusColor(rate: Double, amount: Double, cap: Double) -> Color {
        if rate < 0 {
            return ClayTheme.bad
        }
        if cap > 0, amount >= cap * 0.9 {
            return ClayTheme.accentWarm
        }
        return ClayTheme.good
    }
}

struct BottleneckRow: View {
    @EnvironmentObject private var engine: GameEngine
    let bottlenecks: [String]
    
    var body: some View {
        HStack(spacing: 6) {
            Text("Bottlenecks".uppercased())
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.75)
            ForEach(bottlenecks, id: \.self) { resourceId in
                let def = engine.content.resourcesById[resourceId]
                HStack(spacing: 4) {
                    ResourceIconView(resourceId: resourceId, size: 10, tint: Color(hex: def?.colorHex ?? "#8EC5FF"))
                    Text(def?.name ?? resourceId.capitalized)
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.text)
                        .claySingleLine(minScale: 0.75)
                }
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

struct RiskCard: View {
    let title: String
    let value: Double
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.75)
            Text(String(format: "%.2f", value))
                .font(ClayFonts.data(13, weight: .bold))
                .foregroundColor(accent)
                .claySingleLine(minScale: 0.75)
            SimpleProgressBar(value: min(1.0, max(0, value)))
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

struct MetricCard: View {
    let title: String
    let value: Double
    let accent: Color
    let displayValue: String?

    init(title: String, value: Double, accent: Color, displayValue: String? = nil) {
        self.title = title
        self.value = value
        self.accent = accent
        self.displayValue = displayValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            Text(displayValue ?? String(format: "%.2f", value))
                .font(ClayFonts.data(13, weight: .bold))
                .foregroundColor(accent)
            SimpleProgressBar(value: min(1.0, max(0, value)))
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

struct DecisionPanel: View {
    @EnvironmentObject private var engine: GameEngine
    let chain: EventChainDefinition

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chain.title.uppercased())
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
                .claySingleLine(minScale: 0.8)
            Text(chain.description)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
                .clayTwoLines(minScale: 0.9)
            HStack(spacing: 8) {
                ForEach(chain.choices) { choice in
                    ClayButton(isEnabled: true, active: true) {
                        engine.resolveEventChoice(chainId: chain.id, choiceId: choice.id)
                    } label: {
                        Text(choice.title)
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

struct MetahumanDecisionPanel: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let chain: EventChainDefinition
    let metahuman: MetahumanDefinition
    @State private var pulse = false

    var body: some View {
        let affinity = engine.state.metahumans[metahuman.id]?.affinity ?? 0
        let disposition = engine.state.metahumans[metahuman.id]?.disposition ?? .neutral
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                MetahumanPortraitView(name: metahuman.name, accent: accentColor, spriteId: spriteId)
                    .frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 6) {
                    Text(metahuman.name.uppercased())
                        .font(ClayFonts.display(12, weight: .bold))
                        .foregroundColor(accentColor)
                        .claySingleLine(minScale: 0.75)
                    Text(chain.description)
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                        .clayTwoLines(minScale: 0.9)
                    HStack(spacing: 6) {
                        MetahumanTag(text: "Encounter", tint: accentColor)
                        MetahumanTag(text: "Decision", tint: ClayTheme.accentWarm)
                        MetahumanTag(text: metahuman.role, tint: accentColor)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                MetahumanAffinityMeter(affinity: affinity, accent: accentColor)
                MetahumanDispositionBadge(disposition: disposition, accent: accentColor)
                Spacer()
                MetahumanSignalView(accent: accentColor)
                    .frame(width: 120, height: 10)
            }
            if !metahuman.powers.isEmpty {
                HStack(spacing: 6) {
                    ForEach(metahuman.powers.prefix(4), id: \.self) { power in
                        MetahumanPowerTag(text: power, tint: accentColor)
                    }
                }
            }
            if disposition != .neutral {
                let effects = disposition == .ally ? metahuman.allyPassiveEffects : metahuman.enemyPassiveEffects
                if !effects.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active Influence")
                            .font(ClayFonts.display(9, weight: .semibold))
                            .foregroundColor(ClayTheme.muted)
                            .claySingleLine(minScale: 0.8)
                        HStack(spacing: 6) {
                            ForEach(effects.indices, id: \.self) { index in
                                let effect = effects[index]
                                Text(EffectDescriptor.describe(effect, content: engine.content))
                                    .font(ClayFonts.data(8))
                                    .foregroundColor(ClayTheme.text)
                                    .claySingleLine(minScale: 0.7)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .fill(ClayTheme.panel)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(accentColor.opacity(0.4), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your approach")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.8)
                ForEach(chain.choices) { choice in
                    MetahumanChoiceCard(chainId: chain.id, choice: choice, accent: accentColor)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panelElevated)
                .overlay(MetahumanBackdropView(accent: accentColor).opacity(reduceMotion ? 0 : 1))
                .overlay(
                    MetahumanPulseOverlay(active: pulse, accent: accentColor)
                        .opacity(reduceMotion ? 0 : 1)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(accentColor.opacity(0.5), lineWidth: 1)
        )
        .onAppear { pulse = true }
    }

    private var accentColor: Color {
        return Color(hex: metahuman.accentHex)
    }

    private var spriteId: String {
        engine.metahumanSpriteId(metahuman)
    }
}

struct MetahumanPortraitView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let name: String
    let accent: Color
    let spriteId: String

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let rotation = Angle(degrees: (time.truncatingRemainder(dividingBy: 6.0) / 6.0) * 360.0)
            let scan = CGFloat(sin(time * 1.6)) * 14
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(colors: [accent.opacity(0.35), ClayTheme.panelElevated], center: .center, startRadius: 4, endRadius: 42)
                    )
                Circle()
                    .stroke(accent.opacity(0.15), lineWidth: 6)
                Circle()
                    .stroke(
                        AngularGradient(colors: [accent.opacity(0.2), accent.opacity(0.8), accent.opacity(0.2)], center: .center),
                        lineWidth: 2
                    )
                    .rotationEffect(reduceMotion ? .zero : rotation)
                if !reduceMotion {
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [Color.clear, accent.opacity(0.45), Color.clear], startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 46, height: 10)
                        .offset(y: scan)
                        .clipShape(Circle())
                        .blendMode(.screen)
                }
                PixelSpriteView(spriteId: spriteId, size: 32, tint: accent, isActive: !reduceMotion)
            }
        }
        .clipShape(Circle())
    }
}

struct MetahumanPulseOverlay: View {
    let active: Bool
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
            .stroke(accent.opacity(pulse ? 0.4 : 0.1), lineWidth: 1)
            .scaleEffect(pulse ? 1.01 : 0.99)
            .animation(reduceMotion ? .default : .easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear {
                guard active else { return }
                pulse = true
            }
    }
}

struct MetahumanBackdropView: View {
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let shift = CGFloat((time.truncatingRemainder(dividingBy: 8.0) / 8.0) * 200)
            ZStack {
                LinearGradient(
                    colors: [accent.opacity(0.08), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                if !reduceMotion {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, accent.opacity(0.12), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 36)
                        .offset(x: shift - 100, y: -40)
                        .rotationEffect(.degrees(-8))
                        .blendMode(.screen)
                }
            }
        }
    }
}

struct MetahumanTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text.uppercased())
            .font(ClayFonts.display(8, weight: .semibold))
            .foregroundColor(tint)
            .claySingleLine(minScale: 0.6)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
    }
}

struct MetahumanChoiceCard: View {
    @EnvironmentObject private var engine: GameEngine
    let chainId: String
    let choice: EventChoiceDefinition
    let accent: Color
    @State private var hovered = false

    var body: some View {
        Button {
            engine.resolveEventChoice(chainId: chainId, choiceId: choice.id)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(choice.title)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.accentText)
                    .claySingleLine(minScale: 0.75)
                Text(choice.description)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.accentText.opacity(0.85))
                    .clayTwoLines(minScale: 0.9)
                let effectLines = choice.effects.map { EffectDescriptor.describe($0, content: engine.content) }
                if !effectLines.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(effectLines.prefix(3), id: \.self) { line in
                            Text(line)
                                .font(ClayFonts.data(8))
                                .foregroundColor(ClayTheme.accentText)
                                .claySingleLine(minScale: 0.7)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.white.opacity(0.15))
                                )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(accent.opacity(hovered ? 0.95 : 0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.25), radius: 6, x: 0, y: 2)
        .scaleEffect(hovered ? 1.01 : 1.0)
        .onHover { hovering in
            hovered = hovering
        }
    }
}

private struct MetahumanDispositionBadge: View {
    let disposition: MetahumanDisposition
    let accent: Color

    var body: some View {
        let text: String
        let tint: Color
        switch disposition {
        case .ally:
            text = "ALLY"
            tint = ClayTheme.good
        case .enemy:
            text = "ENEMY"
            tint = ClayTheme.bad
        case .neutral:
            text = "NEUTRAL"
            tint = accent
        }
        return Text(text)
            .font(ClayFonts.display(8, weight: .semibold))
            .foregroundColor(tint)
            .claySingleLine(minScale: 0.6)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
    }
}

private struct MetahumanSignalView: View {
    let accent: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let phase = CGFloat((time.truncatingRemainder(dividingBy: 2.0) / 2.0))
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(ClayTheme.panelElevated)
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.1), accent.opacity(0.6), accent.opacity(0.1)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: reduceMotion ? 0 : (phase * 80) - 40)
                    .mask(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .frame(height: 6)
                    )
            }
        }
    }
}
