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
}

struct AutoRenewPanel: View {
    @EnvironmentObject private var engine: GameEngine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Auto-Renew".uppercased())
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
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
                Spacer()
                Text(relationshipLabel(state?.relationship ?? 0))
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(Color(hex: relationshipColor(state?.relationship ?? 0)))
            }
            Text(faction.description)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.muted)
            if let active = state?.activeContracts, !active.isEmpty {
                Text("Active Contracts")
                    .font(ClayFonts.display(10, weight: .semibold))
                ForEach(active) { contract in
                    if let def = engine.content.contractsById[contract.contractId] {
                        HStack {
                            Text(def.name)
                            Spacer()
                            Text(contract.remainingSeconds.clayTimeString)
                        }
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                    }
                }
            }
            Divider()
            Text("Available Contracts")
                .font(ClayFonts.display(10, weight: .semibold))
            ForEach(availableContracts(), id: \.id) { contract in
                let blockReason = engine.contractBlockReason(contract)
                let isEnabled = blockReason == nil
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contract.name)
                            .font(ClayFonts.display(10, weight: .semibold))
                        Text(contract.description)
                            .font(ClayFonts.data(9))
                            .foregroundColor(ClayTheme.muted)
                    }
                    Spacer()
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
}
