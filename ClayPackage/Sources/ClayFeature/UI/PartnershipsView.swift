import SwiftUI

struct PartnershipsView: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Partnerships", subtitle: "Secure contracts for steady inflow and security.")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let message = engine.partnershipAdvisorMessage() {
                        HintBanner(message: message, tone: .info)
                    }
                    if !expiringContracts().isEmpty {
                        SoftCard(title: "Expiring Soon") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(expiringContracts(), id: \.id) { contract in
                                    ContractAlertRow(contract: contract)
                                }
                            }
                        }
                    }
                    if !recommendedContracts().isEmpty {
                        SoftCard(title: "Recommended Contracts") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(recommendedContracts(), id: \.id) { contract in
                                    RecommendedContractRow(contract: contract)
                                }
                            }
                        }
                    }
                    AutoRenewPanel()
                    ForEach(engine.content.pack.factions, id: \.id) { faction in
                        FactionCard(faction: faction)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 20)
            }
        }
    }

    private func expiringContracts() -> [ContractDefinition] {
        let expiring = engine.state.factionStates.values
            .flatMap(\.activeContracts)
            .filter { $0.remainingSeconds < 3600 }
        return expiring.compactMap { engine.content.contractsById[$0.contractId] }
    }

    private func recommendedContracts() -> [ContractDefinition] {
        let available = engine.content.pack.contracts.filter { engine.state.flags["contract:\($0.id)"] == true }
        let filtered = available.filter { engine.contractBlockReason($0) == nil }
        return filtered.prefix(3).map { $0 }
    }
}

private struct ContractAlertRow: View {
    let contract: ContractDefinition

    var body: some View {
        HStack(spacing: 8) {
            KenneyIconView(path: "KenneySelected/Icons/icon_cart.png", size: 12, tint: ClayTheme.accentWarm)
            VStack(alignment: .leading, spacing: 2) {
                Text(contract.name)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Text("Expiring soon")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.85)
            }
            Spacer(minLength: 0)
            InlineStatusPill(text: "Renew", tint: ClayTheme.accentWarm)
        }
        .padding(6)
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

private struct RecommendedContractRow: View {
    @EnvironmentObject private var engine: GameEngine
    let contract: ContractDefinition

    var body: some View {
        let blockReason = engine.contractBlockReason(contract)
        HStack(spacing: 8) {
            KenneyIconView(path: "KenneySelected/Icons/icon_link.png", size: 12, tint: ClayTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(contract.name)
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Text(contract.description)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.85)
            }
            Spacer(minLength: 0)
            ClayButton(isEnabled: blockReason == nil, blockedMessage: blockReason) {
                engine.startContract(contract)
            } label: {
                Text("Start")
            }
        }
        .padding(6)
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

struct AutoRenewPanel: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Auto-Renew".uppercased())
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                    .claySingleLine(minScale: 0.8)
                Spacer()
                SimpleToggle(label: "", isOn: Binding(get: { engine.state.autoPlanRules.autoRenewContracts }, set: { engine.setAutoRenewContracts($0) }))
            }
            Text("Automatically renew eligible contracts one hour before expiration.")
                .font(ClayFonts.data(9))
                .foregroundColor(ClayTheme.muted)
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

struct FactionCard: View {
    @EnvironmentObject private var engine: GameEngine
    let faction: FactionDefinition
    
    var body: some View {
        let state = engine.state.factionStates[faction.id]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                PixelSpriteView(spriteId: spriteId(), size: 14)
                Text(faction.name.uppercased())
                    .font(ClayFonts.display(11, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Spacer()
                Text(relationshipLabel(state?.relationship ?? 0))
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(Color(hex: relationshipColor(state?.relationship ?? 0)))
                    .claySingleLine(minScale: 0.7)
            }
            Text(faction.description)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
                .clayTwoLines(minScale: 0.9)
            if let active = state?.activeContracts, !active.isEmpty {
                Text("Active Contracts")
                    .font(ClayFonts.display(10, weight: .semibold))
                    .claySingleLine(minScale: 0.8)
                ForEach(active) { contract in
                    if let def = engine.content.contractsById[contract.contractId] {
                        HStack {
                            Text(def.name)
                                .claySingleLine(minScale: 0.75)
                            Spacer()
                            Text(contract.remainingSeconds.clayTimeString)
                                .monospacedDigit()
                                .claySingleLine(minScale: 0.8)
                        }
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                    }
                }
            }
            Divider()
            Text("Available Contracts")
                .font(ClayFonts.display(10, weight: .semibold))
                .claySingleLine(minScale: 0.8)
            ForEach(availableContracts(), id: \.id) { contract in
                let blockReason = engine.contractBlockReason(contract)
                let isEnabled = blockReason == nil
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contract.name)
                            .font(ClayFonts.display(10, weight: .semibold))
                            .claySingleLine(minScale: 0.75)
                        Text(contract.description)
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.muted)
                            .clayTwoLines(minScale: 0.9)
                    }
                    Spacer()
                    InlineStatusPill(text: upkeepStatus(contract).label, tint: upkeepStatus(contract).tint)
                    ClayButton(isEnabled: isEnabled, blockedMessage: blockReason) {
                        engine.startContract(contract)
                    } label: {
                        Text("Start")
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }

    private func spriteId() -> String {
        switch faction.id {
        case "caravans":
            return "dispatch"
        case "forge_cities":
            return "work"
        case "archivists":
            return "work"
        case "raiders":
            return "worker"
        default:
            return "work"
        }
    }
    
    private func availableContracts() -> [ContractDefinition] {
        engine.content.pack.contracts.filter { $0.factionId == faction.id && engine.state.flags["contract:\($0.id)"] == true }
    }
    
    private func relationshipLabel(_ value: Int) -> String {
        switch value {
        case -2: return "Hostile"
        case -1: return "Wary"
        case 0: return "Neutral"
        case 1: return "Partner"
        default: return "Allied"
        }
    }
    
    private func relationshipColor(_ value: Int) -> String {
        switch value {
        case -2: return "#F28B82"
        case -1: return "#F2C14E"
        case 0: return "#8C9BA8"
        case 1: return "#8FD3FE"
        default: return "#A8E6A3"
        }
    }

    private func upkeepStatus(_ contract: ContractDefinition) -> (label: String, tint: Color) {
        let affordable = contract.upkeepPerHour.allSatisfy { resourceId, amount in
            let current = engine.state.resources[resourceId]?.amount ?? 0
            return current >= amount
        }
        if affordable {
            return ("Upkeep OK", ClayTheme.good)
        }
        return ("Upkeep Low", ClayTheme.accentWarm)
    }
}
