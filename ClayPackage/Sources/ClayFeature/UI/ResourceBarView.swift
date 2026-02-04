import SwiftUI
import AppKit

struct ResourceBarView: View {
    @EnvironmentObject private var engine: GameEngine
    @State private var selectedResourceId: String? = nil
    @State private var cacheBurstToken = 0
    
    var body: some View {
        let sorted = engine.content.pack.resources.sorted { $0.sortOrder < $1.sortOrder }
        HStack(spacing: 16) {
            ForEach(sorted, id: \.id) { resource in
                let state = engine.state.resources[resource.id]
                let rate = engine.derived.resourceRatesPerHour[resource.id, default: 0]
                let cap = engine.derived.resourceCaps[resource.id, default: state?.cap ?? 0]
                let activity: HUDChipActivity = {
                    let amount = state?.amount ?? 0
                    if cap > 0 && amount >= cap * 0.9 {
                        return .warning
                    }
                    if rate < 0 {
                        return .negative
                    }
                    if rate > 0 {
                        return .positive
                    }
                    return .idle
                }()
                Button {
                    selectedResourceId = resource.id
                } label: {
                    HUDChip(
                        title: resource.name,
                        value: "\(state?.amount.clayFormatted ?? "0") / \(cap.clayFormatted)",
                        subvalue: "\(rate >= 0 ? "+" : "")\(rate.clayFormatted)/h",
                        color: Color(hex: resource.colorHex),
                        iconPath: nil,
                        resourceId: resource.id,
                        activity: activity
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            Spacer()
            let cacheTotal = engine.state.collector.storedByResource.values.reduce(0, +)
            ZStack {
                if cacheTotal > 0 {
                    CacheButton(amount: cacheTotal, onCollect: {
                        cacheBurstToken += 1
                        engine.collectCache()
                    }) {
                        HStack(spacing: 6) {
                            KenneyIconView(path: "KenneySelected/Icons/icon_save.png", size: 12, tint: ClayTheme.accentText)
                            Text("Cache \(cacheTotal.clayFormatted)")
                        }
                    }
                } else {
                    Color.clear
                        .frame(width: 120, height: 32)
                }
                CoinBurstView(trigger: cacheBurstToken, icon: cacheBurstIcon, color: ClayTheme.accentWarm)
                    .offset(y: -6)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("ERA")
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                Text(engine.content.erasById[engine.state.eraId]?.name ?? "Unknown")
                    .font(ClayFonts.display(12, weight: .semibold))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(ClayTheme.panel)
        .overlay(
            Rectangle()
                .fill(ClayTheme.stroke.opacity(0.6))
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
