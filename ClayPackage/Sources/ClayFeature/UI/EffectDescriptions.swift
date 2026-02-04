import Foundation

struct EffectDescriptor {
    static func describe(_ effect: EffectDefinition, content: ContentCatalog) -> String {
        switch effect.type {
        case "add_resource_cap":
            if let resourceId = effect.resourceId, let amount = effect.amount {
                let name = content.resourcesById[resourceId]?.name ?? resourceId.capitalized
                return "Cap +\(amount.clayFormatted) \(name)"
            }
        case "add_resource_multiplier":
            if let resourceId = effect.resourceId, let multiplier = effect.multiplier {
                let name = content.resourcesById[resourceId]?.name ?? resourceId.capitalized
                let percent = Int((multiplier - 1) * 100)
                return "+\(percent)% \(name)"
            }
        case "add_global_multiplier":
            if let multiplier = effect.multiplier {
                let percent = Int((multiplier - 1) * 100)
                return "+\(percent)% Global Output"
            }
        case "grant_resource":
            if let resourceId = effect.resourceId, let amount = effect.amount {
                let name = content.resourcesById[resourceId]?.name ?? resourceId.capitalized
                let sign = amount >= 0 ? "+" : ""
                return "\(sign)\(amount.clayFormatted) \(name)"
            }
        case "add_crew":
            if let count = effect.crewCount {
                return "+\(count) Crew"
            }
        case "project_speed_bonus":
            if let amount = effect.amount {
                let percent = Int(amount * 100)
                return "+\(percent)% Project Speed"
            }
        case "add_security_bonus":
            if let amount = effect.amount {
                return "+\(amount.clayFormatted) Security"
            }
        case "add_logistics_cap":
            if let amount = effect.amount {
                return "+\(amount.clayFormatted) Logistics"
            }
        case "unlock_building":
            if let buildingId = effect.buildingId {
                let name = content.buildingsById[buildingId]?.name ?? buildingId
                return "Unlock \(name)"
            }
        case "unlock_project":
            if let projectId = effect.projectId {
                let name = content.projectsById[projectId]?.name ?? projectId
                return "Unlock \(name)"
            }
        case "unlock_era":
            if let eraId = effect.eraId {
                let name = content.erasById[eraId]?.name ?? eraId
                return "Unlock \(name) Era"
            }
        case "adjust_faction":
            if let factionId = effect.factionId, let amount = effect.amount {
                let name = content.factionsById[factionId]?.name ?? factionId.capitalized
                let sign = amount >= 0 ? "+" : ""
                return "\(name) \(sign)\(Int(amount))"
            }
        case "set_flag":
            if let flagId = effect.flagId {
                return "Flag \(flagId.replacingOccurrences(of: "_", with: " "))"
            }
        case "adjust_metahuman_affinity":
            if let metaId = effect.metahumanId, let amount = effect.amount {
                let name = content.metahumansById[metaId]?.name ?? metaId.capitalized
                let sign = amount >= 0 ? "+" : ""
                return "\(name) Affinity \(sign)\(Int(amount))"
            }
        default:
            break
        }
        return "Effect"
    }
}
