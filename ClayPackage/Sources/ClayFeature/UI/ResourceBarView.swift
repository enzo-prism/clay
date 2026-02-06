import SwiftUI
import AppKit

struct ResourceBarView: View {
    @EnvironmentObject private var engine: GameEngine
    @Environment(\.eraTheme) private var eraTheme
    @State private var selectedResourceId: String? = nil
    @State private var cacheBurstToken = 0
    
    var body: some View {
        let sorted = engine.content.pack.resources.sorted { $0.sortOrder < $1.sortOrder }
        HStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sorted, id: \.id) { resource in
                        let state = engine.state.resources[resource.id]
                        let rate = engine.derived.resourceRatesPerHour[resource.id, default: 0]
                        let cap = engine.derived.resourceCaps[resource.id, default: state?.cap ?? 0]
                        Button {
                            selectedResourceId = resource.id
                        } label: {
                            ResourceBarChip(
                                title: resource.name,
                                amount: state?.amount ?? 0,
                                cap: cap,
                                rate: rate,
                                color: Color(hex: resource.colorHex),
                                resourceId: resource.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            AtRiskGroup()
                .layoutPriority(1)

            let cacheTotal = engine.state.collector.storedByResource.values.reduce(0, +)
            ZStack {
                if cacheTotal > 0 {
                    CacheButton(amount: cacheTotal, onCollect: {
                        cacheBurstToken += 1
                        engine.collectCache()
                    }) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 6) {
                                KenneyIconView(path: "KenneySelected/Icons/icon_save.png", size: 12, tint: ClayTheme.accentText)
                                Text("Collect \(cacheTotal.clayFormatted)")
                                    .claySingleLine(minScale: 0.85)
                            }
                            HStack(spacing: 6) {
                                KenneyIconView(path: "KenneySelected/Icons/icon_save.png", size: 12, tint: ClayTheme.accentText)
                                Text("Collect")
                                    .claySingleLine(minScale: 0.9)
                            }
                            KenneyIconView(path: "KenneySelected/Icons/icon_save.png", size: 12, tint: ClayTheme.accentText)
                                .accessibilityLabel("Collect cache")
                        }
                        .frame(minWidth: 44)
                    }
                    .help("Collect cached resources")
                } else {
                    Color.clear
                        .frame(width: 44, height: 32)
                }
                CoinBurstView(trigger: cacheBurstToken, icon: cacheBurstIcon, color: ClayTheme.accentWarm)
                    .offset(y: -6)
            }
            .layoutPriority(2)

            VStack(alignment: .trailing, spacing: 2) {
                Text("ERA")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(eraTheme.accent)
                    .claySingleLine(minScale: 0.8)
                Text(engine.content.erasById[engine.state.eraId]?.name ?? "Unknown")
                    .font(ClayFonts.display(12, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
            }
            .frame(minWidth: 120, alignment: .trailing)
            .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
                .frame(height: 1),
            alignment: .bottom
        )
        .sheet(isPresented: Binding(
            get: { selectedResourceId != nil },
            set: { if !$0 { selectedResourceId = nil } }
        )) {
            if let resourceId = selectedResourceId {
                ResourceDetailView(resourceId: resourceId)
                    .environmentObject(engine)
            }
        }
    }

    private var cacheBurstIcon: NSImage? {
        if let icon = PixelAssetCatalog.shared.iconImage(for: PixelAssetCatalog.shared.resourceIcon(for: "credits")) {
            return icon
        }
        if let path = KenneyAssetCatalog.shared.resourceIconPath(for: "credits"),
           let image = KenneyAssetCatalog.shared.image(for: path) {
            return image
        }
        return nil
    }
}

private struct ResourceBarChip: View {
    let title: String
    let amount: Double
    let cap: Double
    let rate: Double
    let color: Color
    let resourceId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ResourceIconView(resourceId: resourceId, size: 12, tint: color)
                Text(title.uppercased())
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(color)
                    .claySingleLine(minScale: 0.75)
            }
            Text("\(amount.clayFormatted) / \(cap.clayFormatted)")
                .font(ClayFonts.data(11, weight: .medium))
                .foregroundColor(ClayTheme.text)
                .claySingleLine(minScale: 0.7)
            Text("\(rate >= 0 ? "+" : "")\(rate.clayFormatted)/h | \(statusText())")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.7)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(statusTint().opacity(0.5), lineWidth: 1)
        )
    }

    private func statusText() -> String {
        if cap > 0 && amount >= cap * 0.95 {
            return "Near cap"
        }
        if rate < 0 {
            let hours = amount / max(0.1, abs(rate))
            return "Empty in \(TimeInterval(hours * 3600).clayTimeString)"
        }
        if cap > 0 && rate > 0 {
            let hours = (cap - amount) / rate
            return "Cap in \(TimeInterval(hours * 3600).clayTimeString)"
        }
        return "Stable"
    }

    private func statusTint() -> Color {
        if cap > 0 && amount >= cap * 0.9 {
            return ClayTheme.accentWarm
        }
        if rate < 0 {
            return ClayTheme.bad
        }
        if rate > 0 {
            return ClayTheme.good
        }
        return ClayTheme.stroke
    }
}

private struct AtRiskGroup: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        let caps = engine.derived.resourceCaps
        let nearCap = engine.state.resources.filter { resource in
            let cap = caps[resource.key, default: 0]
            return cap > 0 && resource.value.amount >= cap * 0.9
        }.count
        let negativeRates = engine.derived.resourceRatesPerHour.filter { $0.value < 0 }.count
        let raidChance = Int(engine.derived.risk.raidChancePerHour * 100)
        VStack(alignment: .trailing, spacing: 4) {
            Text("AT RISK")
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.8)
            HStack(spacing: 8) {
                RiskItem(label: "Cap", value: "\(nearCap)", tint: nearCap > 0 ? ClayTheme.accentWarm : ClayTheme.muted, icon: "KenneySelected/Icons/icon_bars.png")
                RiskItem(label: "Net", value: "\(negativeRates)", tint: negativeRates > 0 ? ClayTheme.bad : ClayTheme.muted, icon: "KenneySelected/Icons/icon_power.png")
                RiskItem(label: "Raid", value: "\(raidChance)%", tint: raidChance > 12 ? ClayTheme.bad : ClayTheme.muted, icon: "KenneySelected/Icons/icon_target.png")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
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

private struct RiskItem: View {
    let label: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            KenneyIconView(path: icon, size: 10, tint: tint)
            Text(label.uppercased())
                .font(ClayFonts.display(8, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
                .claySingleLine(minScale: 0.7)
            Text(value)
                .font(ClayFonts.data(9, weight: .semibold))
                .foregroundColor(tint)
                .claySingleLine(minScale: 0.7)
        }
    }
}

private struct CacheButton<Label: View>: View {
    let amount: Double
    let onCollect: () -> Void
    let label: () -> Label
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false
    @State private var glow = false

    var body: some View {
        ClayButton(isEnabled: true, active: true) {
            onCollect()
        } label: {
            label()
                .offset(y: bob ? -1 : 1)
                .animation(reduceMotion ? .none : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: bob)
        }
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.accentWarm.opacity(glow ? 0.9 : 0.45), lineWidth: 1)
        )
        .shadow(color: ClayTheme.accentWarm.opacity(glow ? 0.35 : 0.15), radius: glow ? 8 : 4, x: 0, y: 2)
        .onAppear {
            guard !reduceMotion else { return }
            bob = true
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
