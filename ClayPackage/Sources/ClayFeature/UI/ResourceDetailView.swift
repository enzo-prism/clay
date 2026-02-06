import SwiftUI

struct ResourceDetailView: View {
    @EnvironmentObject private var engine: GameEngine
    let resourceId: String
    
    var body: some View {
        let definition = engine.content.resourcesById[resourceId]
        let name = definition?.name ?? resourceId.capitalized
        let amount = engine.state.resources[resourceId]?.amount ?? 0
        let cap = engine.derived.resourceCaps[resourceId, default: 0]
        let rate = engine.derived.resourceRatesPerHour[resourceId, default: 0]
        let status = generationStatus(rate: rate)
        
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ResourceIconView(resourceId: resourceId, size: 22, tint: ClayTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(ClayFonts.display(16, weight: .bold))
                        .claySingleLine(minScale: 0.75)
                    Text(resourceId.uppercased())
                        .font(ClayFonts.data(9))
                        .foregroundColor(ClayTheme.muted)
                        .claySingleLine(minScale: 0.8)
                }
                Spacer()
                Text(status.label.uppercased())
                    .font(ClayFonts.display(9, weight: .semibold))
                    .foregroundColor(status.color)
                    .claySingleLine(minScale: 0.7)
            }
            
            Panel(title: "Overview") {
                HStack {
                    StatPair(title: "Current", value: amount.clayFormatted, accent: ClayTheme.text)
                    StatPair(title: "Cap", value: cap.clayFormatted, accent: ClayTheme.muted)
                    StatPair(title: "Net / hr", value: formattedRate(rate), accent: status.color)
                }
                if let timeToCap = timeToCapString(amount: amount, cap: cap, rate: rate) {
                    Text("Time to cap: \(timeToCap)")
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                }
            }
            
            Panel(title: "Used For") {
                ForEach(usageLines(), id: \.self) { line in
                    Text("• \(line)")
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                }
            }
            
            Panel(title: "How To Get More") {
                let producers = topProducers()
                if producers.isEmpty {
                    Text("• Unlock buildings and contracts that produce \(name).")
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                } else {
                    ForEach(producers, id: \.0) { producer in
                        Text("• \(producer.0) (+\(producer.1.clayFormatted)/hr)")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    }
                }
                let contracts = topContracts()
                if !contracts.isEmpty {
                    ForEach(contracts, id: \.0) { contract in
                        Text("• Contract: \(contract.0) (+\(contract.1.clayFormatted)/hr)")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    }
                }
                let dispatches = topDispatches()
                if !dispatches.isEmpty {
                    ForEach(dispatches, id: \.0) { dispatch in
                        Text("• Dispatch: \(dispatch.0) (+\(dispatch.1.clayFormatted))")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    }
                }
                let bonuses = unlockedDomainBonuses()
                if !bonuses.isEmpty {
                    ForEach(bonuses, id: \.self) { bonus in
                        Text("• Domain Bonus: \(bonus)")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 420)
        .background(ClayTheme.bg)
    }
    
    private func formattedRate(_ rate: Double) -> String {
        let sign = rate >= 0 ? "+" : ""
        return "\(sign)\(rate.clayFormatted)"
    }
    
    private func timeToCapString(amount: Double, cap: Double, rate: Double) -> String? {
        guard cap > 0 else { return nil }
        if amount >= cap {
            return "At cap"
        }
        guard rate > 0 else {
            return "No growth"
        }
        let seconds = ((cap - amount) / rate) * 3600
        return TimeInterval(seconds).clayTimeString
    }
    
    private func generationStatus(rate: Double) -> (label: String, color: Color) {
        if rate <= 0 {
            return ("Stalled", ClayTheme.bad)
        } else if rate < 1 {
            return ("Low", ClayTheme.accentWarm)
        } else if rate < 5 {
            return ("Moderate", ClayTheme.accent)
        } else {
            return ("Strong", ClayTheme.good)
        }
    }
    
    private func usageLines() -> [String] {
        let buildings = engine.content.pack.buildings
        let projects = engine.content.pack.projects
        let contracts = engine.content.pack.contracts
        
        var lines: [String] = []
        if buildings.contains(where: { ($0.baseCost[resourceId] ?? 0) > 0 }) {
            lines.append("Building construction and upgrades")
        }
        if projects.contains(where: { ($0.costs[resourceId] ?? 0) > 0 }) {
            lines.append("Project investments")
        }
        if buildings.contains(where: { ($0.maintenancePerHour[resourceId] ?? 0) > 0 }) {
            lines.append("Operational maintenance")
        }
        if contracts.contains(where: { ($0.upkeepPerHour[resourceId] ?? 0) > 0 }) {
            lines.append("Contract upkeep")
        }
        if lines.isEmpty {
            lines.append("No known uses yet")
        }
        return lines
    }
    
    private func topProducers() -> [(String, Double)] {
        engine.content.pack.buildings
            .compactMap { def -> (String, Double)? in
                let amount = def.productionPerHour[resourceId, default: 0]
                return amount > 0 ? (def.name, amount) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0 }
    }
    
    private func topContracts() -> [(String, Double)] {
        engine.content.pack.contracts
            .compactMap { contract -> (String, Double)? in
                let amount = contract.effectsPerHour[resourceId, default: 0]
                return amount > 0 ? (contract.name, amount) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { $0 }
    }

    private func topDispatches() -> [(String, Double)] {
        engine.content.pack.dispatches
            .compactMap { dispatch -> (String, Double)? in
                let amount = dispatch.rewards[resourceId, default: 0]
                return amount > 0 ? (dispatch.name, amount) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(2)
            .map { $0 }
    }

    private func unlockedDomainBonuses() -> [String] {
        var bonuses: [String] = []
        for domain in engine.content.pack.domains {
            let unlockedTier = engine.state.domainState.unlockedTiersByDomain[domain.id, default: 0]
            guard unlockedTier > 0 else { continue }
            for tier in domain.tiers where tier.tier <= unlockedTier {
                for effect in tier.effects {
                    guard effect.resourceId == resourceId else { continue }
                    let summary = EffectDescriptor.describe(effect, content: engine.content)
                    bonuses.append("\(domain.name): \(summary)")
                }
            }
        }
        return bonuses
    }
}

private struct StatPair: View {
    let title: String
    let value: String
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            Text(value)
                .font(ClayFonts.data(13, weight: .semibold))
                .foregroundColor(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
