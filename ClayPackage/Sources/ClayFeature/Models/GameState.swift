import Foundation

public struct ResourceState: Codable {
    public var amount: Double
    public var cap: Double
}

public struct BuildingInstance: Codable, Identifiable {
    public var id: UUID
    public var buildingId: String
    public var level: Int
    public var x: Int
    public var y: Int
    public var disabledUntil: Date?
}

public struct ProjectInstance: Codable, Identifiable {
    public var id: UUID
    public var projectId: String
    public var remainingSeconds: Double
    public var totalSeconds: Double
    public var crewRequired: Int
    public var startedAt: Date
    public var source: ProjectSource
    public var associatedBuildingId: UUID?
}

public struct QueuedProject: Codable, Identifiable {
    public var id: UUID
    public var projectId: String
    public var queuedAt: Date
    public var source: ProjectSource
}

public enum ProjectSource: String, Codable {
    case research
    case buildingConstruction
    case buildingUpgrade
    case accelerator
    case megaproject
}

public struct ContractInstance: Codable, Identifiable {
    public var id: UUID
    public var contractId: String
    public var factionId: String
    public var remainingSeconds: Double
    public var upkeepMissed: Bool
}

public struct FactionState: Codable {
    public var relationship: Int
    public var activeContracts: [ContractInstance]
}

public struct CatalystState: Codable {
    public var availableAt: Date
    public var activeProjectId: UUID?
    public var activeUntil: Date?
    public var level: Int
}

public struct MarketState: Codable {
    public var priceIndexByResource: [String: Double]
    public var lastUpdatedAt: Date
}

public struct LogisticsState: Codable {
    public var logisticsCapacity: Double
    public var logisticsDemand: Double
    public var logisticsFactor: Double
}

public struct PolicyState: Codable {
    public var activePoliciesBySlot: [String: String]
    public var cooldownsByPolicyId: [String: Date]
}

public struct DomainState: Codable {
    public var pointsByDomain: [String: Int]
    public var unlockedTiersByDomain: [String: Int]
}

public enum DispatchStatus: String, Codable {
    case active
    case ready
    case failed
}

public struct DispatchInstance: Codable, Identifiable {
    public var id: UUID
    public var dispatchId: String
    public var remainingSeconds: Double
    public var startedAt: Date
    public var status: DispatchStatus
}

public struct CollectorState: Codable {
    public var storedByResource: [String: Double]
    public var capacityHours: Double
    public var lastCollectedAt: Date
    public var lastUpdatedAt: Date
}

public struct AutoPlanRules: Codable {
    public var enabled: Bool
    public var priorityTags: [String]
    public var autoRenewContracts: Bool
}

public struct PrestigeState: Codable {
    public var legacyPoints: Int
    public var legacyUpgrades: [String]
    public var lastPrestigeAt: Date?
}

public struct StatsState: Codable {
    public var totalProducedByResource: [String: Double]
    public var totalWastedByResource: [String: Double]
    public var totalRaidLossByResource: [String: Double]
    public var lastEfficiency: Double
    public var lastRaidAt: Date?
    public var dispatchesCompleted: Int
    public var dispatchRewardsByResource: [String: Double]

    enum CodingKeys: String, CodingKey {
        case totalProducedByResource
        case totalWastedByResource
        case totalRaidLossByResource
        case lastEfficiency
        case lastRaidAt
        case dispatchesCompleted
        case dispatchRewardsByResource
    }

    public init(
        totalProducedByResource: [String: Double],
        totalWastedByResource: [String: Double],
        totalRaidLossByResource: [String: Double],
        lastEfficiency: Double,
        lastRaidAt: Date?,
        dispatchesCompleted: Int,
        dispatchRewardsByResource: [String: Double]
    ) {
        self.totalProducedByResource = totalProducedByResource
        self.totalWastedByResource = totalWastedByResource
        self.totalRaidLossByResource = totalRaidLossByResource
        self.lastEfficiency = lastEfficiency
        self.lastRaidAt = lastRaidAt
        self.dispatchesCompleted = dispatchesCompleted
        self.dispatchRewardsByResource = dispatchRewardsByResource
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalProducedByResource = try container.decode([String: Double].self, forKey: .totalProducedByResource)
        totalWastedByResource = try container.decode([String: Double].self, forKey: .totalWastedByResource)
        totalRaidLossByResource = try container.decode([String: Double].self, forKey: .totalRaidLossByResource)
        lastEfficiency = try container.decode(Double.self, forKey: .lastEfficiency)
        lastRaidAt = try container.decodeIfPresent(Date.self, forKey: .lastRaidAt)
        dispatchesCompleted = try container.decodeIfPresent(Int.self, forKey: .dispatchesCompleted) ?? 0
        dispatchRewardsByResource = try container.decodeIfPresent([String: Double].self, forKey: .dispatchRewardsByResource) ?? [:]
    }
}

public struct EventChainState: Codable {
    public var pendingEventChainId: String?
    public var cooldownsByChainId: [String: Date]
}

public struct AlertState: Codable {
    public var lastTriggeredAtById: [String: Date]
}

public enum GuidanceLevel: String, Codable, CaseIterable, Hashable {
    case high
    case balanced
    case minimal
}

public struct SettingsState: Codable {
    public var offlineCapDays: Int
    public var notificationsEnabled: Bool
    public var colorblindMode: Bool
    public var use3DPreviews: Bool
    public var guidanceLevel: GuidanceLevel

    enum CodingKeys: String, CodingKey {
        case offlineCapDays
        case notificationsEnabled
        case colorblindMode
        case use3DPreviews
        case guidanceLevel
    }

    public init(offlineCapDays: Int, notificationsEnabled: Bool, colorblindMode: Bool, use3DPreviews: Bool, guidanceLevel: GuidanceLevel) {
        self.offlineCapDays = offlineCapDays
        self.notificationsEnabled = notificationsEnabled
        self.colorblindMode = colorblindMode
        self.use3DPreviews = use3DPreviews
        self.guidanceLevel = guidanceLevel
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.offlineCapDays = try container.decodeIfPresent(Int.self, forKey: .offlineCapDays) ?? 7
        self.notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        self.colorblindMode = try container.decodeIfPresent(Bool.self, forKey: .colorblindMode) ?? false
        self.use3DPreviews = try container.decodeIfPresent(Bool.self, forKey: .use3DPreviews) ?? true
        self.guidanceLevel = try container.decodeIfPresent(GuidanceLevel.self, forKey: .guidanceLevel) ?? .high
    }
}

public struct RiskState: Codable {
    public var exposure: Double
    public var security: Double
    public var hostility: Double
    public var raidChancePerHour: Double
}

public enum MetahumanDisposition: String, Codable {
    case neutral
    case ally
    case enemy
}

public struct MetahumanState: Codable {
    public var affinity: Int
    public var disposition: MetahumanDisposition
    public var lastEncounterAt: Date?
}

public struct EventLogEntry: Codable, Identifiable {
    public var id: UUID
    public var timestamp: Date
    public var category: String
    public var title: String
    public var message: String
    public var severity: Int
}

public struct GameState: Codable {
    public static let currentVersion = 7
    public var saveVersion: Int
    public var lastSavedAt: Date
    public var lastTickAt: Date
    public var resources: [String: ResourceState]
    public var unlockedBuildingIds: [String]
    public var unlockedProjectIds: [String]
    public var completedProjectIds: [String]
    public var activeProjects: [ProjectInstance]
    public var queuedProjects: [QueuedProject]
    public var crewCount: Int
    public var maxCrew: Int
    public var eraId: String
    public var flags: [String: Bool]
    public var buildings: [BuildingInstance]
    public var factionStates: [String: FactionState]
    public var events: [EventLogEntry]
    public var catalyst: CatalystState
    public var chronoShards: Int
    public var projectSpeedMultiplier: Double
    public var resourceMultipliers: [String: Double]
    public var globalResourceMultiplier: Double
    public var storageAdditions: [String: Double]
    public var securityBonus: Double
    public var logisticsBonus: Double
    public var risk: RiskState
    public var cohesion: Double
    public var biosphere: Double
    public var market: MarketState
    public var logistics: LogisticsState
    public var policyState: PolicyState
    public var domainState: DomainState
    public var dispatches: [DispatchInstance]
    public var collector: CollectorState
    public var chosenMegaprojectFamily: [String: String]
    public var achievementsUnlocked: [String]
    public var autoPlanRules: AutoPlanRules
    public var prestige: PrestigeState
    public var stats: StatsState
    public var metahumans: [String: MetahumanState]
    public var people: PeopleState
    public var eventChains: EventChainState
    public var alerts: AlertState
    public var nextEventInSeconds: Double
    public var gridSize: Int
    public var pendingTimeTravelWarning: Bool
    public var timeTravelClampUntil: Date?
    public var settings: SettingsState

    enum CodingKeys: String, CodingKey {
        case saveVersion
        case lastSavedAt
        case lastTickAt
        case resources
        case unlockedBuildingIds
        case unlockedProjectIds
        case completedProjectIds
        case activeProjects
        case queuedProjects
        case crewCount
        case maxCrew
        case eraId
        case flags
        case buildings
        case factionStates
        case events
        case catalyst
        case chronoShards
        case projectSpeedMultiplier
        case resourceMultipliers
        case globalResourceMultiplier
        case storageAdditions
        case securityBonus
        case logisticsBonus
        case risk
        case cohesion
        case biosphere
        case market
        case logistics
        case policyState
        case domainState
        case dispatches
        case collector
        case chosenMegaprojectFamily
        case achievementsUnlocked
        case autoPlanRules
        case prestige
        case stats
        case metahumans
        case people
        case eventChains
        case alerts
        case nextEventInSeconds
        case gridSize
        case pendingTimeTravelWarning
        case timeTravelClampUntil
        case settings
    }

    public init(
        saveVersion: Int,
        lastSavedAt: Date,
        lastTickAt: Date,
        resources: [String: ResourceState],
        unlockedBuildingIds: [String],
        unlockedProjectIds: [String],
        completedProjectIds: [String],
        activeProjects: [ProjectInstance],
        queuedProjects: [QueuedProject],
        crewCount: Int,
        maxCrew: Int,
        eraId: String,
        flags: [String: Bool],
        buildings: [BuildingInstance],
        factionStates: [String: FactionState],
        events: [EventLogEntry],
        catalyst: CatalystState,
        chronoShards: Int,
        projectSpeedMultiplier: Double,
        resourceMultipliers: [String: Double],
        globalResourceMultiplier: Double,
        storageAdditions: [String: Double],
        securityBonus: Double,
        logisticsBonus: Double,
        risk: RiskState,
        cohesion: Double,
        biosphere: Double,
        market: MarketState,
        logistics: LogisticsState,
        policyState: PolicyState,
        domainState: DomainState,
        dispatches: [DispatchInstance],
        collector: CollectorState,
        chosenMegaprojectFamily: [String: String],
        achievementsUnlocked: [String],
        autoPlanRules: AutoPlanRules,
        prestige: PrestigeState,
        stats: StatsState,
        metahumans: [String: MetahumanState],
        people: PeopleState,
        eventChains: EventChainState,
        alerts: AlertState,
        nextEventInSeconds: Double,
        gridSize: Int,
        pendingTimeTravelWarning: Bool,
        timeTravelClampUntil: Date?,
        settings: SettingsState
    ) {
        self.saveVersion = saveVersion
        self.lastSavedAt = lastSavedAt
        self.lastTickAt = lastTickAt
        self.resources = resources
        self.unlockedBuildingIds = unlockedBuildingIds
        self.unlockedProjectIds = unlockedProjectIds
        self.completedProjectIds = completedProjectIds
        self.activeProjects = activeProjects
        self.queuedProjects = queuedProjects
        self.crewCount = crewCount
        self.maxCrew = maxCrew
        self.eraId = eraId
        self.flags = flags
        self.buildings = buildings
        self.factionStates = factionStates
        self.events = events
        self.catalyst = catalyst
        self.chronoShards = chronoShards
        self.projectSpeedMultiplier = projectSpeedMultiplier
        self.resourceMultipliers = resourceMultipliers
        self.globalResourceMultiplier = globalResourceMultiplier
        self.storageAdditions = storageAdditions
        self.securityBonus = securityBonus
        self.logisticsBonus = logisticsBonus
        self.risk = risk
        self.cohesion = cohesion
        self.biosphere = biosphere
        self.market = market
        self.logistics = logistics
        self.policyState = policyState
        self.domainState = domainState
        self.dispatches = dispatches
        self.collector = collector
        self.chosenMegaprojectFamily = chosenMegaprojectFamily
        self.achievementsUnlocked = achievementsUnlocked
        self.autoPlanRules = autoPlanRules
        self.prestige = prestige
        self.stats = stats
        self.metahumans = metahumans
        self.people = people
        self.eventChains = eventChains
        self.alerts = alerts
        self.nextEventInSeconds = nextEventInSeconds
        self.gridSize = gridSize
        self.pendingTimeTravelWarning = pendingTimeTravelWarning
        self.timeTravelClampUntil = timeTravelClampUntil
        self.settings = settings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saveVersion = try container.decodeIfPresent(Int.self, forKey: .saveVersion) ?? 1
        lastSavedAt = try container.decode(Date.self, forKey: .lastSavedAt)
        lastTickAt = try container.decode(Date.self, forKey: .lastTickAt)
        resources = try container.decode([String: ResourceState].self, forKey: .resources)
        unlockedBuildingIds = try container.decode([String].self, forKey: .unlockedBuildingIds)
        unlockedProjectIds = try container.decode([String].self, forKey: .unlockedProjectIds)
        completedProjectIds = try container.decode([String].self, forKey: .completedProjectIds)
        activeProjects = try container.decode([ProjectInstance].self, forKey: .activeProjects)
        queuedProjects = try container.decodeIfPresent([QueuedProject].self, forKey: .queuedProjects) ?? []
        crewCount = try container.decode(Int.self, forKey: .crewCount)
        maxCrew = try container.decode(Int.self, forKey: .maxCrew)
        eraId = try container.decode(String.self, forKey: .eraId)
        flags = try container.decode([String: Bool].self, forKey: .flags)
        buildings = try container.decode([BuildingInstance].self, forKey: .buildings)
        factionStates = try container.decode([String: FactionState].self, forKey: .factionStates)
        events = try container.decode([EventLogEntry].self, forKey: .events)
        catalyst = try container.decode(CatalystState.self, forKey: .catalyst)
        chronoShards = try container.decode(Int.self, forKey: .chronoShards)
        projectSpeedMultiplier = try container.decode(Double.self, forKey: .projectSpeedMultiplier)
        resourceMultipliers = try container.decode([String: Double].self, forKey: .resourceMultipliers)
        globalResourceMultiplier = try container.decodeIfPresent(Double.self, forKey: .globalResourceMultiplier) ?? 1.0
        storageAdditions = try container.decode([String: Double].self, forKey: .storageAdditions)
        securityBonus = try container.decode(Double.self, forKey: .securityBonus)
        logisticsBonus = try container.decodeIfPresent(Double.self, forKey: .logisticsBonus) ?? 0
        risk = try container.decode(RiskState.self, forKey: .risk)
        cohesion = try container.decodeIfPresent(Double.self, forKey: .cohesion) ?? 0.6
        biosphere = try container.decodeIfPresent(Double.self, forKey: .biosphere) ?? 0.6
        market = try container.decodeIfPresent(MarketState.self, forKey: .market) ?? MarketState(priceIndexByResource: [:], lastUpdatedAt: Date())
        logistics = try container.decodeIfPresent(LogisticsState.self, forKey: .logistics) ?? LogisticsState(logisticsCapacity: 0, logisticsDemand: 0, logisticsFactor: 1)
        policyState = try container.decodeIfPresent(PolicyState.self, forKey: .policyState) ?? PolicyState(activePoliciesBySlot: [:], cooldownsByPolicyId: [:])
        domainState = try container.decodeIfPresent(DomainState.self, forKey: .domainState) ?? DomainState(pointsByDomain: [:], unlockedTiersByDomain: [:])
        dispatches = try container.decodeIfPresent([DispatchInstance].self, forKey: .dispatches) ?? []
        collector = try container.decodeIfPresent(CollectorState.self, forKey: .collector) ?? CollectorState(storedByResource: [:], capacityHours: 12, lastCollectedAt: Date(), lastUpdatedAt: Date())
        chosenMegaprojectFamily = try container.decodeIfPresent([String: String].self, forKey: .chosenMegaprojectFamily) ?? [:]
        achievementsUnlocked = try container.decodeIfPresent([String].self, forKey: .achievementsUnlocked) ?? []
        autoPlanRules = try container.decodeIfPresent(AutoPlanRules.self, forKey: .autoPlanRules) ?? AutoPlanRules(enabled: false, priorityTags: [], autoRenewContracts: false)
        prestige = try container.decodeIfPresent(PrestigeState.self, forKey: .prestige) ?? PrestigeState(legacyPoints: 0, legacyUpgrades: [], lastPrestigeAt: nil)
        stats = try container.decodeIfPresent(StatsState.self, forKey: .stats) ?? StatsState(totalProducedByResource: [:], totalWastedByResource: [:], totalRaidLossByResource: [:], lastEfficiency: 1.0, lastRaidAt: nil, dispatchesCompleted: 0, dispatchRewardsByResource: [:])
        metahumans = try container.decodeIfPresent([String: MetahumanState].self, forKey: .metahumans) ?? [:]
        people = try container.decodeIfPresent(PeopleState.self, forKey: .people) ?? PeopleState(recruitedIds: [], maxRoster: 8)
        eventChains = try container.decodeIfPresent(EventChainState.self, forKey: .eventChains) ?? EventChainState(pendingEventChainId: nil, cooldownsByChainId: [:])
        alerts = try container.decodeIfPresent(AlertState.self, forKey: .alerts) ?? AlertState(lastTriggeredAtById: [:])
        nextEventInSeconds = try container.decode(Double.self, forKey: .nextEventInSeconds)
        gridSize = try container.decode(Int.self, forKey: .gridSize)
        pendingTimeTravelWarning = try container.decode(Bool.self, forKey: .pendingTimeTravelWarning)
        timeTravelClampUntil = try container.decodeIfPresent(Date.self, forKey: .timeTravelClampUntil)
        settings = try container.decode(SettingsState.self, forKey: .settings)
    }
}
