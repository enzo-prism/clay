import Foundation

public typealias ResourceAmount = [String: Double]

public struct ContentPack: Codable {
    public var resources: [ResourceDefinition]
    public var buildings: [BuildingDefinition]
    public var projects: [ProjectDefinition]
    public var eras: [EraDefinition]
    public var factions: [FactionDefinition]
    public var contracts: [ContractDefinition]
    public var events: [EventDefinition]
    public var policies: [PolicyDefinition]
    public var eventChains: [EventChainDefinition]
    public var ambientEntities: [AmbientEntityDefinition]
    public var legacyUpgrades: [LegacyUpgradeDefinition]
    public var metahumans: [MetahumanDefinition]
    public var people: [PeopleDefinition]
    public var domains: [DomainDefinition]
    public var dispatches: [DispatchDefinition]
    public var megaprojectFamilies: [MegaprojectFamilyDefinition]
    public var achievements: [AchievementDefinition]
    public var collector: CollectorDefinition
}

public struct ResourceDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var colorHex: String
    public var icon: String
    public var sortOrder: Int
    public var startingAmount: Double
    public var baseCap: Double
}

public struct BuildingDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var era: String
    public var category: String
    public var maxLevel: Int
    public var baseCost: ResourceAmount
    public var costGrowth: Double
    public var buildTimeSeconds: Double
    public var productionPerHour: ResourceAmount
    public var consumptionPerHour: ResourceAmount
    public var storageCapAdd: ResourceAmount
    public var defenseScore: Double
    public var projectSpeedBonus: Double
    public var adjacencyBonus: AdjacencyBonus?
    public var logisticsCapAdd: Double
    public var districtTag: String?
    public var districtBonus: Double
    public var maintenancePerHour: ResourceAmount
    public var efficiencyFloor: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case era
        case category
        case maxLevel
        case baseCost
        case costGrowth
        case buildTimeSeconds
        case productionPerHour
        case consumptionPerHour
        case storageCapAdd
        case defenseScore
        case projectSpeedBonus
        case adjacencyBonus
        case logisticsCapAdd
        case districtTag
        case districtBonus
        case maintenancePerHour
        case efficiencyFloor
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        era = try container.decode(String.self, forKey: .era)
        category = try container.decode(String.self, forKey: .category)
        maxLevel = try container.decode(Int.self, forKey: .maxLevel)
        baseCost = try container.decode(ResourceAmount.self, forKey: .baseCost)
        costGrowth = try container.decode(Double.self, forKey: .costGrowth)
        buildTimeSeconds = try container.decode(Double.self, forKey: .buildTimeSeconds)
        productionPerHour = try container.decode(ResourceAmount.self, forKey: .productionPerHour)
        consumptionPerHour = try container.decode(ResourceAmount.self, forKey: .consumptionPerHour)
        storageCapAdd = try container.decode(ResourceAmount.self, forKey: .storageCapAdd)
        defenseScore = try container.decode(Double.self, forKey: .defenseScore)
        projectSpeedBonus = try container.decode(Double.self, forKey: .projectSpeedBonus)
        adjacencyBonus = try container.decodeIfPresent(AdjacencyBonus.self, forKey: .adjacencyBonus)
        logisticsCapAdd = try container.decodeIfPresent(Double.self, forKey: .logisticsCapAdd) ?? 0
        districtTag = try container.decodeIfPresent(String.self, forKey: .districtTag)
        districtBonus = try container.decodeIfPresent(Double.self, forKey: .districtBonus) ?? 1.0
        maintenancePerHour = try container.decodeIfPresent(ResourceAmount.self, forKey: .maintenancePerHour) ?? [:]
        efficiencyFloor = try container.decodeIfPresent(Double.self, forKey: .efficiencyFloor) ?? 0
    }
}

public struct AdjacencyBonus: Codable {
    public var requiresBuildingId: String
    public var multiplier: Double
}

public struct ProjectDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var era: String
    public var category: String
    public var durationSeconds: Double
    public var crewRequired: Int
    public var costs: ResourceAmount
    public var effects: [EffectDefinition]
    public var description: String
    public var tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case era
        case category
        case durationSeconds
        case crewRequired
        case costs
        case effects
        case description
        case tags
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        era = try container.decode(String.self, forKey: .era)
        category = try container.decode(String.self, forKey: .category)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        crewRequired = try container.decode(Int.self, forKey: .crewRequired)
        costs = try container.decode(ResourceAmount.self, forKey: .costs)
        effects = try container.decode([EffectDefinition].self, forKey: .effects)
        description = try container.decode(String.self, forKey: .description)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

public struct EffectDefinition: Codable {
    public var type: String
    public var resourceId: String?
    public var amount: Double?
    public var multiplier: Double?
    public var buildingId: String?
    public var projectId: String?
    public var eraId: String?
    public var crewCount: Int?
    public var flagId: String?
    public var contractId: String?
    public var factionId: String?
    public var metahumanId: String?
}

public struct EraDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var sortOrder: Int
    public var keystoneProjectId: String
    public var unlocksBuildingIds: [String]
    public var unlocksProjectIds: [String]
    public var description: String
}

public struct FactionDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
}

public struct ContractDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var factionId: String
    public var requiredRelationship: Int
    public var durationSeconds: Double
    public var upkeepPerHour: ResourceAmount
    public var effectsPerHour: ResourceAmount
    public var multipliers: ResourceAmount
    public var securityBonus: Double
    public var description: String
    public var priceIndexMultiplier: Double
    public var renewable: Bool
    public var penaltyEffects: [EffectDefinition]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case factionId
        case requiredRelationship
        case durationSeconds
        case upkeepPerHour
        case effectsPerHour
        case multipliers
        case securityBonus
        case description
        case priceIndexMultiplier
        case renewable
        case penaltyEffects
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        factionId = try container.decode(String.self, forKey: .factionId)
        requiredRelationship = try container.decode(Int.self, forKey: .requiredRelationship)
        durationSeconds = try container.decode(Double.self, forKey: .durationSeconds)
        upkeepPerHour = try container.decode(ResourceAmount.self, forKey: .upkeepPerHour)
        effectsPerHour = try container.decode(ResourceAmount.self, forKey: .effectsPerHour)
        multipliers = try container.decode(ResourceAmount.self, forKey: .multipliers)
        securityBonus = try container.decode(Double.self, forKey: .securityBonus)
        description = try container.decode(String.self, forKey: .description)
        priceIndexMultiplier = try container.decodeIfPresent(Double.self, forKey: .priceIndexMultiplier) ?? 1.0
        renewable = try container.decodeIfPresent(Bool.self, forKey: .renewable) ?? false
        penaltyEffects = try container.decodeIfPresent([EffectDefinition].self, forKey: .penaltyEffects) ?? []
    }
}

public struct EventDefinition: Codable, Identifiable {
    public var id: String
    public var category: String
    public var title: String
    public var description: String
    public var weight: Double
}

public struct PolicyDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var slot: String
    public var era: String
    public var effects: [EffectDefinition]
    public var cooldownSeconds: Double
    public var description: String
}

public struct EventTriggerDefinition: Codable {
    public var minExposure: Double?
    public var minSecurity: Double?
    public var minHostility: Double?
    public var resourceAtCapId: String?
    public var requiresEraId: String?
    public var requiresContractId: String?
    public var requiresFlag: String?
    public var requiresLogisticsBelow: Double?
}

public struct EventChoiceDefinition: Codable, Identifiable {
    public var id: String
    public var title: String
    public var description: String
    public var effects: [EffectDefinition]
    public var nextId: String?
}

public struct EventChainDefinition: Codable, Identifiable {
    public var id: String
    public var title: String
    public var description: String
    public var trigger: EventTriggerDefinition
    public var choices: [EventChoiceDefinition]
    public var effects: [EffectDefinition]
    public var nextIds: [String]
    public var cooldownSeconds: Double
    public var uniqueFlagId: String?
}

public struct AmbientSpawnRulesDefinition: Codable {
    public var minEraId: String?
    public var maxCount: Int?
    public var perBuildingId: String?
    public var baseCount: Int?
}

public struct AmbientMovementProfileDefinition: Codable {
    public var speed: Double
    public var radius: Double
    public var pauseSeconds: Double
}

public struct AmbientEntityDefinition: Codable, Identifiable {
    public var id: String
    public var model3d: String
    public var spawnRules: AmbientSpawnRulesDefinition
    public var movementProfile: AmbientMovementProfileDefinition
    public var scale: Double
}

public struct MetahumanDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var role: String
    public var accentHex: String
    public var powers: [String]
    public var allySummary: String
    public var enemySummary: String
    public var allyPassiveEffects: [EffectDefinition]
    public var enemyPassiveEffects: [EffectDefinition]
    public var spriteId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case role
        case accentHex
        case powers
        case allySummary
        case enemySummary
        case allyPassiveEffects
        case enemyPassiveEffects
        case spriteId
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        role = try container.decode(String.self, forKey: .role)
        accentHex = try container.decode(String.self, forKey: .accentHex)
        powers = try container.decode([String].self, forKey: .powers)
        allySummary = try container.decode(String.self, forKey: .allySummary)
        enemySummary = try container.decode(String.self, forKey: .enemySummary)
        allyPassiveEffects = try container.decode([EffectDefinition].self, forKey: .allyPassiveEffects)
        enemyPassiveEffects = try container.decode([EffectDefinition].self, forKey: .enemyPassiveEffects)
        spriteId = try container.decodeIfPresent(String.self, forKey: .spriteId)
    }
}

public struct LegacyUpgradeDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var cost: Int
    public var effects: [EffectDefinition]
    public var description: String
}

public struct DomainDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var iconPath: String
    public var tags: [String]
    public var tiers: [DomainTierDefinition]
}

public struct DomainTierDefinition: Codable {
    public var tier: Int
    public var requiredPoints: Int
    public var effects: [EffectDefinition]
}

public struct DispatchDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var durationSeconds: Double
    public var requiredCrew: Int
    public var rewards: ResourceAmount
    public var riskChance: Double
    public var era: String
    public var tags: [String]
}

public struct MegaprojectFamilyDefinition: Codable, Identifiable {
    public var familyId: String
    public var choices: [String]
    public var exclusive: Bool
    public var description: String

    public var id: String { familyId }
}

public struct AchievementCondition: Codable {
    public var type: String
    public var resourceId: String?
    public var amount: Double?
    public var durationHours: Double?
    public var domainId: String?
    public var tier: Int?
    public var flagId: String?
}

public struct AchievementDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var condition: AchievementCondition
    public var effects: [EffectDefinition]
}

public struct CollectorDefinition: Codable {
    public var capacityHours: Double
}
