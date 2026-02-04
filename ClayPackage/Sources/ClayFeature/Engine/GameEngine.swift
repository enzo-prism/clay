import Foundation
import SwiftUI

public struct DerivedState {
    public var resourceRatesPerHour: [String: Double]
    public var resourceCaps: [String: Double]
    public var timeToCapHours: [String: Double?]
    public var activeCrewCount: Int
    public var availableCrewCount: Int
    public var projectSpeedMultiplier: Double
    public var risk: RiskState
    public var logistics: LogisticsState
    public var averageEfficiency: Double
    public var marketIndexByResource: [String: Double]
}

struct PolicyModifiers {
    var resourceMultipliers: [String: Double] = [:]
    var globalMultiplier: Double = 1.0
    var projectSpeedBonus: Double = 0
    var securityBonus: Double = 0
    var logisticsBonus: Double = 0
    var storageAdditions: [String: Double] = [:]
}

@MainActor
public final class GameEngine: ObservableObject {
    @Published public private(set) var state: GameState
    @Published public private(set) var derived: DerivedState
    
    public let content: ContentCatalog
    
    private var tickTimer: Timer?
    private var autosaveTimer: Timer?
    private var rng: SeededGenerator
    
    public init(seed: UInt64? = nil, shouldStartTimers: Bool = true, loadPersistence: Bool = true) {
        let content = ContentLoader.load()
        let initialState = loadPersistence ? (Persistence.load() ?? GameEngine.defaultState(content: content)) : GameEngine.defaultState(content: content)
        let seedValue = seed ?? UInt64(Date().timeIntervalSince1970)
        self.rng = SeededGenerator(seed: seedValue)
        self.content = content
        self.state = initialState
        self.derived = GameEngine.computeDerived(state: initialState, content: content)
        migrateIfNeeded()
        reconcileOffline(now: Date())
        if shouldStartTimers {
            startTimers()
        }
    }
    
    public func startTimers() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        autosaveTimer?.invalidate()
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.state.lastSavedAt = Date()
                Persistence.save(state: self.state)
            }
        }
    }
    
    public func stopTimers() {
        tickTimer?.invalidate()
        autosaveTimer?.invalidate()
        state.lastSavedAt = Date()
        Persistence.save(state: state)
    }

    public func resolveTimeTravel(allow: Bool) {
        state.pendingTimeTravelWarning = false
        if allow {
            state.timeTravelClampUntil = nil
            state.lastSavedAt = Date()
        }
    }

    public func setOfflineCapDays(_ days: Int) {
        updateSettings { $0.offlineCapDays = days }
    }
    
    public func setNotificationsEnabled(_ enabled: Bool) {
        updateSettings { $0.notificationsEnabled = enabled }
    }
    
    public func setColorblindMode(_ enabled: Bool) {
        updateSettings { $0.colorblindMode = enabled }
    }

    public func setUse3DPreviews(_ enabled: Bool) {
        updateSettings { $0.use3DPreviews = enabled }
    }

    private func updateSettings(_ update: (inout SettingsState) -> Void) {
        var settings = state.settings
        update(&settings)
        state.settings = settings
    }

    private func migrateIfNeeded() {
        guard state.saveVersion < GameState.currentVersion else { return }
        if state.market.priceIndexByResource.isEmpty {
            var indices: [String: Double] = [:]
            for resource in content.pack.resources {
                indices[resource.id] = 1.0
            }
            state.market.priceIndexByResource = indices
        }
        if state.stats.totalProducedByResource.isEmpty {
            for resource in content.pack.resources {
                state.stats.totalProducedByResource[resource.id] = 0
                state.stats.totalWastedByResource[resource.id] = 0
                state.stats.totalRaidLossByResource[resource.id] = 0
            }
        }
        if state.alerts.lastTriggeredAtById.isEmpty {
            state.alerts = AlertState(lastTriggeredAtById: [:])
        }
        if state.domainState.pointsByDomain.isEmpty {
            var points: [String: Int] = [:]
            var tiers: [String: Int] = [:]
            for domain in content.pack.domains {
                points[domain.id] = 0
                tiers[domain.id] = 0
            }
            state.domainState = DomainState(pointsByDomain: points, unlockedTiersByDomain: tiers)
        }
        if state.collector.capacityHours <= 0 {
            state.collector.capacityHours = content.pack.collector.capacityHours
        }
        if state.collector.storedByResource.isEmpty {
            for resource in content.pack.resources {
                state.collector.storedByResource[resource.id] = 0
            }
        }
        if state.stats.lastRaidAt == nil {
            state.stats.lastRaidAt = state.lastSavedAt
        }
        if state.metahumans.isEmpty {
            var states: [String: MetahumanState] = [:]
            for meta in content.pack.metahumans {
                let allyFlag = "metahuman:\(meta.id):ally"
                let enemyFlag = "metahuman:\(meta.id):enemy"
                let disposition: MetahumanDisposition
                let affinity: Int
                if state.flags[allyFlag] == true {
                    disposition = .ally
                    affinity = 2
                } else if state.flags[enemyFlag] == true {
                    disposition = .enemy
                    affinity = -2
                } else {
                    disposition = .neutral
                    affinity = 0
                }
                states[meta.id] = MetahumanState(affinity: affinity, disposition: disposition, lastEncounterAt: nil)
            }
            state.metahumans = states
        }
        if state.people.recruitedIds.isEmpty && state.people.maxRoster == 0 {
            state.people = PeopleState(recruitedIds: [], maxRoster: 8)
        }
        state.saveVersion = GameState.currentVersion
    }

    private func policyModifiers() -> PolicyModifiers {
        var modifiers = PolicyModifiers()
        let now = Date()
        for (_, policyId) in state.policyState.activePoliciesBySlot {
            if let cooldown = state.policyState.cooldownsByPolicyId[policyId], cooldown > now {
                continue
            }
            guard let policy = content.policiesById[policyId] else { continue }
            for effect in policy.effects {
                applyModifier(effect, to: &modifiers)
            }
        }
        applyMetahumanPassives(to: &modifiers)
        applyPeoplePassives(to: &modifiers)
        return modifiers
    }

    private func applyMetahumanPassives(to modifiers: inout PolicyModifiers) {
        for meta in content.pack.metahumans {
            guard let state = state.metahumans[meta.id] else { continue }
            switch state.disposition {
            case .ally:
                for effect in meta.allyPassiveEffects {
                    applyModifier(effect, to: &modifiers)
                }
            case .enemy:
                for effect in meta.enemyPassiveEffects {
                    applyModifier(effect, to: &modifiers)
                }
            case .neutral:
                continue
            }
        }
    }

    private func applyPeoplePassives(to modifiers: inout PolicyModifiers) {
        for personId in state.people.recruitedIds {
            guard let person = personDefinition(for: personId) else { continue }
            for effect in person.effects {
                applyModifier(effect, to: &modifiers)
            }
        }
    }

    private func applyModifier(_ effect: EffectDefinition, to modifiers: inout PolicyModifiers) {
        switch effect.type {
        case "add_resource_multiplier":
            if let resourceId = effect.resourceId, let multiplier = effect.multiplier {
                modifiers.resourceMultipliers[resourceId, default: 1.0] *= multiplier
            }
        case "add_global_multiplier":
            if let multiplier = effect.multiplier {
                modifiers.globalMultiplier *= multiplier
            }
        case "project_speed_bonus":
            if let amount = effect.amount {
                modifiers.projectSpeedBonus += amount
            }
        case "add_security_bonus":
            if let amount = effect.amount {
                modifiers.securityBonus += amount
            }
        case "add_logistics_cap":
            if let amount = effect.amount {
                modifiers.logisticsBonus += amount
            }
        case "add_resource_cap":
            if let resourceId = effect.resourceId, let amount = effect.amount {
                modifiers.storageAdditions[resourceId, default: 0] += amount
            }
        default:
            break
        }
    }

    public func setAutoPlannerEnabled(_ enabled: Bool) {
        state.autoPlanRules.enabled = enabled
    }

    public func setAutoPlanTag(_ tag: String, enabled: Bool) {
        var tags = Set(state.autoPlanRules.priorityTags)
        if enabled {
            tags.insert(tag)
        } else {
            tags.remove(tag)
        }
        state.autoPlanRules.priorityTags = Array(tags).sorted()
    }

    public func setAutoRenewContracts(_ enabled: Bool) {
        state.autoPlanRules.autoRenewContracts = enabled
    }

    public func setPolicy(slot: String, policyId: String?) {
        if let policyId {
            guard let policy = content.policiesById[policyId] else { return }
            let now = Date()
            if let cooldown = state.policyState.cooldownsByPolicyId[policyId], cooldown > now {
                return
            }
            guard isPolicyUnlocked(policy) else { return }
            state.policyState.activePoliciesBySlot[slot] = policyId
            state.policyState.cooldownsByPolicyId[policyId] = now.addingTimeInterval(policy.cooldownSeconds)
        } else {
            state.policyState.activePoliciesBySlot.removeValue(forKey: slot)
        }
    }

    private func isPolicyUnlocked(_ policy: PolicyDefinition) -> Bool {
        guard let requiredEra = content.erasById[policy.era],
              let currentEra = content.erasById[state.eraId] else { return false }
        return currentEra.sortOrder >= requiredEra.sortOrder
    }

    private func isEraUnlocked(_ eraId: String) -> Bool {
        guard let requiredEra = content.erasById[eraId],
              let currentEra = content.erasById[state.eraId] else { return false }
        return currentEra.sortOrder >= requiredEra.sortOrder
    }

    public func availableLegacyGain() -> Int {
        var points = 0
        for era in content.pack.eras where era.sortOrder > 0 {
            if state.completedProjectIds.contains(era.keystoneProjectId) {
                points += 1
            }
        }
        if state.flags["type_iii_complete"] == true {
            let energy = max(1, state.stats.totalProducedByResource["energy", default: 0])
            let bonus = Int(max(0, floor(log10(energy)) - 8))
            points += bonus
        }
        return points
    }

    public func purchaseLegacyUpgrade(_ upgradeId: String) {
        guard let upgrade = content.legacyUpgradesById[upgradeId] else { return }
        guard !state.prestige.legacyUpgrades.contains(upgradeId) else { return }
        guard state.prestige.legacyPoints >= upgrade.cost else { return }
        state.prestige.legacyPoints -= upgrade.cost
        state.prestige.legacyUpgrades.append(upgradeId)
        applyEffects(upgrade.effects)
    }

    public func ascend() {
        let gain = availableLegacyGain()
        var prestige = state.prestige
        let settings = state.settings
        prestige.legacyPoints += gain
        prestige.lastPrestigeAt = Date()
        let newState = GameEngine.defaultState(content: content)
        state = newState
        state.prestige = prestige
        state.settings = settings
        applyLegacyUpgrades()
        derived = GameEngine.computeDerived(state: state, content: content)
    }

    private func applyLegacyUpgrades() {
        for upgradeId in state.prestige.legacyUpgrades {
            if let upgrade = content.legacyUpgradesById[upgradeId] {
                applyEffects(upgrade.effects)
            }
        }
    }

    private func runAutoPlanner() {
        guard state.autoPlanRules.enabled else { return }
        guard state.queuedProjects.isEmpty else { return }
        var crewAvailable = availableCrewCount()
        guard crewAvailable > 0 else { return }
        let activeProjects = Set(state.activeProjects.map(\.projectId))
        let unlocked = Set(state.unlockedProjectIds)
        let completed = Set(state.completedProjectIds)
        let priorityTags = Set(state.autoPlanRules.priorityTags)
        let candidates = content.pack.projects.filter { project in
            unlocked.contains(project.id) && !completed.contains(project.id) && !activeProjects.contains(project.id)
        }
        let sorted = candidates.sorted { lhs, rhs in
            let lhsPriority = !priorityTags.isEmpty && !priorityTags.isDisjoint(with: Set(lhs.tags))
            let rhsPriority = !priorityTags.isEmpty && !priorityTags.isDisjoint(with: Set(rhs.tags))
            if lhsPriority != rhsPriority {
                return lhsPriority && !rhsPriority
            }
            return lhs.durationSeconds < rhs.durationSeconds
        }
        for project in sorted where crewAvailable > 0 {
            if canAfford(costs: project.costs) {
                startProject(projectId: project.id, source: .research)
                crewAvailable = availableCrewCount()
            }
        }
    }

    private func autoRenewContracts() {
        guard state.autoPlanRules.autoRenewContracts else { return }
        for (factionId, var faction) in state.factionStates {
            for index in faction.activeContracts.indices {
                var contract = faction.activeContracts[index]
                guard contract.remainingSeconds < 3600 else { continue }
                guard let def = content.contractsById[contract.contractId], def.renewable else { continue }
                guard faction.relationship >= def.requiredRelationship else { continue }
                guard canAfford(costs: def.upkeepPerHour) else { continue }
                contract.remainingSeconds += def.durationSeconds
                contract.upkeepMissed = false
                faction.activeContracts[index] = contract
                addEvent(category: "contract", title: "Contract Renewed", message: def.name)
            }
            state.factionStates[factionId] = faction
        }
    }

    private func processQueuedProjects() {
        guard !state.queuedProjects.isEmpty else { return }
        var crewAvailable = availableCrewCount()
        guard crewAvailable > 0 else { return }
        var startedIds: [UUID] = []
        for queued in state.queuedProjects {
            guard crewAvailable > 0 else { break }
            guard let project = content.projectsById[queued.projectId] else { continue }
            if canAfford(costs: project.costs),
               availableCrewCount() >= project.crewRequired {
                startProject(projectId: project.id, source: queued.source)
                crewAvailable = availableCrewCount()
                startedIds.append(queued.id)
            }
        }
        if !startedIds.isEmpty {
            state.queuedProjects.removeAll { startedIds.contains($0.id) }
        }
    }

    public func projectAdvisorMessage() -> String? {
        if state.logistics.logisticsFactor < 0.7 {
            return "Logistics bottleneck detected. Consider building a Logistics Hub."
        }
        let caps = computeResourceCaps(policy: policyModifiers())
        for (resourceId, resource) in state.resources {
            let cap = caps[resourceId, default: resource.cap]
            if cap > 0 && resource.amount >= cap * 0.9 {
                return "\(resourceId.capitalized) nearing cap. Invest in storage or spend resources."
            }
        }
        let rates = computeResourceRatesPerHour()
        if let worst = rates.min(by: { $0.value < $1.value }), worst.value < 0 {
            return "Net \(worst.key.capitalized) is negative. Boost production or reduce upkeep."
        }
        return nil
    }

    public func projectBlockReason(_ project: ProjectDefinition) -> String? {
        if let reason = megaprojectBlockReason(projectId: project.id) {
            return reason
        }
        if availableCrewCount() < project.crewRequired {
            return "No available crews"
        }
        if !canAfford(costs: project.costs) {
            return missingResourceMessage(for: project.costs)
        }
        return nil
    }

    public func projectQueueBlockReason(_ project: ProjectDefinition) -> String? {
        if let reason = megaprojectBlockReason(projectId: project.id) {
            return reason
        }
        if state.completedProjectIds.contains(project.id) {
            return "Project already completed"
        }
        if state.activeProjects.contains(where: { $0.projectId == project.id }) {
            return "Project already active"
        }
        if state.queuedProjects.contains(where: { $0.projectId == project.id }) {
            return "Project already queued"
        }
        if !state.unlockedProjectIds.contains(project.id) {
            return "Project locked"
        }
        return nil
    }

    private func megaprojectBlockReason(projectId: String) -> String? {
        guard let family = content.pack.megaprojectFamilies.first(where: { $0.choices.contains(projectId) }) else {
            return nil
        }
        if family.exclusive {
            if let chosen = state.chosenMegaprojectFamily[family.familyId], chosen != projectId {
                return "Locked by \(family.description)"
            }
            let activeChoice = state.activeProjects.first { family.choices.contains($0.projectId) && $0.projectId != projectId }
            let queuedChoice = state.queuedProjects.first { family.choices.contains($0.projectId) && $0.projectId != projectId }
            let completedChoice = state.completedProjectIds.first { family.choices.contains($0) && $0 != projectId }
            if activeChoice != nil || queuedChoice != nil || completedChoice != nil {
                return "Another Type II path already chosen"
            }
        }
        return nil
    }

    public func contractBlockReason(_ contract: ContractDefinition) -> String? {
        let relationship = state.factionStates[contract.factionId]?.relationship ?? 0
        if relationship < contract.requiredRelationship {
            return "Relationship too low"
        }
        if let faction = state.factionStates[contract.factionId],
           faction.activeContracts.contains(where: { $0.contractId == contract.id }) {
            return "Contract already active"
        }
        return nil
    }

    public func buildBlockReason(buildingId: String) -> String? {
        guard let def = content.buildingsById[buildingId] else { return "Building locked" }
        if availableCrewCount() < 1 {
            return "No available crews"
        }
        if !canAfford(costs: def.baseCost) {
            return missingResourceMessage(for: def.baseCost)
        }
        return nil
    }

    public func upgradeBlockReason(_ building: BuildingInstance) -> String? {
        guard let def = content.buildingsById[building.buildingId] else { return "Upgrade locked" }
        if building.level >= def.maxLevel {
            return "Max level reached"
        }
        if availableCrewCount() < 1 {
            return "No available crews"
        }
        let cost = scaledCost(base: def.baseCost, growth: def.costGrowth, level: building.level + 1)
        if !canAfford(costs: cost) {
            return missingResourceMessage(for: cost)
        }
        return nil
    }

    public func upgradePreview(for building: BuildingInstance) -> UpgradePreview? {
        guard let def = content.buildingsById[building.buildingId] else { return nil }
        guard building.level < def.maxLevel else { return nil }
        let nextLevel = building.level + 1
        let cost = scaledCost(base: def.baseCost, growth: def.costGrowth, level: nextLevel)
        let duration = def.buildTimeSeconds * pow(1.3, Double(building.level)) / max(0.1, computeProjectSpeedMultiplier())
        let adjacency = adjacencyMultiplier(for: building, definition: def)
        let district = districtMultiplier(for: building, definition: def)
        let oldMultiplier = pow(1.15, Double(building.level - 1)) * adjacency * district
        let newMultiplier = pow(1.15, Double(nextLevel - 1)) * adjacency * district
        let productionDelta = scaleDelta(def.productionPerHour, old: oldMultiplier, new: newMultiplier)
        let consumptionDelta = scaleDelta(def.consumptionPerHour, old: oldMultiplier, new: newMultiplier)
        let storageOld = pow(1.12, Double(building.level - 1))
        let storageNew = pow(1.12, Double(nextLevel - 1))
        let storageDelta = scaleDelta(def.storageCapAdd, old: storageOld, new: storageNew)
        let logisticsOld = pow(1.1, Double(building.level - 1))
        let logisticsNew = pow(1.1, Double(nextLevel - 1))
        let logisticsDelta = def.logisticsCapAdd * (logisticsNew - logisticsOld)
        let projectSpeedDelta = def.projectSpeedBonus
        let defenseDelta = 0.0
        return UpgradePreview(
            cost: cost,
            durationSeconds: duration,
            deltaProductionPerHour: productionDelta,
            deltaConsumptionPerHour: consumptionDelta,
            deltaStorageCap: storageDelta,
            deltaLogisticsCap: logisticsDelta,
            deltaProjectSpeed: projectSpeedDelta,
            deltaDefense: defenseDelta
        )
    }

    public func policyBlockReason(_ policy: PolicyDefinition) -> String? {
        if !isPolicyUnlocked(policy) {
            return "Policy locked by era"
        }
        if let cooldown = state.policyState.cooldownsByPolicyId[policy.id], cooldown > Date() {
            return "Policy on cooldown"
        }
        return nil
    }

    public func personBlockReason(_ person: PeopleDefinition) -> String? {
        if state.people.recruitedIds.contains(person.id) {
            return "Already recruited"
        }
        if state.people.recruitedIds.count >= state.people.maxRoster {
            return "Roster full"
        }
        if !isEraUnlocked(person.era) {
            return "Locked by era"
        }
        if !canAfford(costs: person.costs) {
            return missingResourceMessage(for: person.costs)
        }
        return nil
    }

    public func recruitPerson(_ person: PeopleDefinition) {
        if let reason = personBlockReason(person) {
            NotificationCenter.default.post(name: .clayToast, object: ToastPayload(message: reason, style: .warning))
            return
        }
        spend(costs: person.costs)
        state.people.recruitedIds.append(person.id)
        addEvent(category: "system", title: "Recruit Joined", message: "\(person.name) joined your roster.")
    }

    public func catalystBlockReason(projectId: UUID) -> String? {
        guard state.activeProjects.contains(where: { $0.id == projectId }) else { return "Select an active project" }
        if Date() < state.catalyst.availableAt {
            return "Catalyst on cooldown"
        }
        return nil
    }

    public func shardBlockReason(projectId: UUID) -> String? {
        guard state.activeProjects.contains(where: { $0.id == projectId }) else { return "Select an active project" }
        if state.chronoShards <= 0 {
            return "No Chrono Shards"
        }
        return nil
    }

    private func missingResourceMessage(for costs: ResourceAmount) -> String {
        for (resourceId, cost) in costs {
            if (state.resources[resourceId]?.amount ?? 0) < cost {
                if let def = content.resourcesById[resourceId] {
                    return "Insufficient \(def.name)"
                }
                return "Insufficient \(resourceId.capitalized)"
            }
        }
        return "Insufficient resources"
    }

    public func partnershipAdvisorMessage() -> String? {
        if state.risk.raidChancePerHour > 0.15 {
            return "Raid risk is elevated. Consider a Security Pact."
        }
        let creditsRate = computeResourceRatesPerHour()["credits", default: 0]
        if creditsRate < 1 {
            return "Credits are tight. Export surplus via trade contracts."
        }
        return nil
    }

    public func peopleDefinitions() -> [PeopleDefinition] {
        let core = content.pack.people
        let generated = generatedPeopleDefinitions()
        return core + generated
    }

    public func personDefinition(for id: String) -> PeopleDefinition? {
        if let person = content.peopleById[id] {
            return person
        }
        if id.hasPrefix("auto:") {
            let spriteId = String(id.dropFirst("auto:".count))
            return makeGeneratedPerson(spriteId: spriteId)
        }
        return nil
    }

    public func availablePeople() -> [PeopleDefinition] {
        peopleDefinitions().filter { !state.people.recruitedIds.contains($0.id) }
    }

    public func peopleSpritePool() -> [String] {
        var ids: [String] = []
        for personId in state.people.recruitedIds {
            if let person = personDefinition(for: personId) {
                ids.append(person.spriteId)
            }
        }
        for meta in content.pack.metahumans {
            ids.append(metahumanSpriteId(meta))
        }
        let packIds = PixelAssetCatalog.shared.peoplePackSpriteIds
        if ids.isEmpty {
            ids = packIds
        } else if !packIds.isEmpty {
            ids.append(contentsOf: packIds.prefix(12))
        }
        let basePool = PixelAssetCatalog.shared.pack.characterSprites.keys.sorted()
        let reserved = Set(ids)
        let extras = basePool.filter { !reserved.contains($0) }.prefix(24)
        ids.append(contentsOf: extras)
        if ids.isEmpty {
            ids = Array(basePool)
        }
        let unique = Array(Set(ids))
        return unique.filter { PixelAssetCatalog.shared.sprite(for: $0) != nil }
    }

    public func metahumanSpriteId(_ meta: MetahumanDefinition) -> String {
        let disposition = state.metahumans[meta.id]?.disposition ?? .neutral
        let stateSpriteId = "metahuman_\(meta.id)_\(disposition.rawValue)"
        if PixelAssetCatalog.shared.sprite(for: stateSpriteId) != nil {
            return stateSpriteId
        }
        if let spriteId = meta.spriteId, PixelAssetCatalog.shared.sprite(for: spriteId) != nil {
            return spriteId
        }
        let packIds = PixelAssetCatalog.shared.peoplePackSpriteIds
        if !packIds.isEmpty {
            let index = abs(meta.id.hashValue) % packIds.count
            return packIds[index]
        }
        return "worker"
    }

    private func generatedPeopleDefinitions() -> [PeopleDefinition] {
        let packIds = PixelAssetCatalog.shared.peoplePackSpriteIds
        guard !packIds.isEmpty else { return [] }
        let reserved = Set(content.pack.people.map { $0.spriteId } + content.pack.metahumans.compactMap { $0.spriteId })
        return packIds
            .filter { !reserved.contains($0) }
            .prefix(200)
            .map { makeGeneratedPerson(spriteId: $0) }
    }

    private func makeGeneratedPerson(spriteId: String) -> PeopleDefinition {
        let name = spriteId
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        let costs: ResourceAmount = [
            "food": 6,
            "materials": 4
        ]
        return PeopleDefinition(
            id: "auto:\(spriteId)",
            name: name.isEmpty ? "Citizen" : name,
            description: "A citizen eager to help your settlement.",
            era: "stone",
            role: "Citizen",
            spriteId: spriteId,
            costs: costs,
            effects: [],
            rarity: "common"
        )
    }
    
    private func tick() {
        let now = Date()
        if let clampUntil = state.timeTravelClampUntil, now < clampUntil {
            state.lastTickAt = now
            return
        }
        let delta = now.timeIntervalSince(state.lastTickAt)
        guard delta > 0 else { return }
        advance(by: delta, now: now, isOffline: false)
    }
    
    public func reconcileOffline(now: Date) {
        let elapsed = now.timeIntervalSince(state.lastSavedAt)
        if elapsed < -60 {
            state.pendingTimeTravelWarning = true
            state.timeTravelClampUntil = state.lastSavedAt
            state.lastTickAt = now
            return
        }
        let capSeconds = Double(state.settings.offlineCapDays) * 86_400.0
        let clamped = min(max(0, elapsed), capSeconds)
        if elapsed > capSeconds {
            addEvent(category: "system", title: "Offline Cap Reached", message: "Offline progress capped at \(state.settings.offlineCapDays) days.")
        }
        advance(by: clamped, now: now, isOffline: true)
    }
    
    private func advance(by seconds: Double, now: Date, isOffline: Bool) {
        let policy = policyModifiers()
        updateMarket(now: now)
        state.logistics = computeLogisticsState(policy: policy)
        applyProjectProgress(seconds: seconds)
        applyDispatchProgress(seconds: seconds, now: now)
        applyContractProgress(seconds: seconds)
        applyResourceDelta(seconds: seconds, start: state.lastTickAt, end: now, policy: policy)
        processEvents(seconds: seconds, offline: isOffline)
        processQueuedProjects()
        if !isOffline {
            runAutoPlanner()
            autoRenewContracts()
        }
        state.lastTickAt = now
        state.risk = computeRiskState(policy: policy)
        derived = GameEngine.computeDerived(state: state, content: content)
        evaluateAchievements(now: now)
        if !isOffline {
            emitMilestoneAlerts(now: now)
        }
    }

    private func updateMarket(now: Date) {
        var last = state.market.lastUpdatedAt
        while last.addingTimeInterval(3600) <= now {
            last = last.addingTimeInterval(3600)
            for resource in content.pack.resources {
                let current = state.market.priceIndexByResource[resource.id, default: 1.0]
                let meanRevert = (1.0 - current) * 0.1
                let shock = random(in: -0.04...0.04)
                let updated = min(1.4, max(0.6, current + meanRevert + shock))
                state.market.priceIndexByResource[resource.id] = updated
            }
        }
        state.market.lastUpdatedAt = last
    }

    private func random(in range: ClosedRange<Double>) -> Double {
        let upper = range.upperBound
        let lower = range.lowerBound
        let value = Double.random(in: 0...1, using: &rng)
        return lower + (upper - lower) * value
    }

    private func emitMilestoneAlerts(now: Date) {
        guard state.settings.notificationsEnabled else { return }
        let cooldown: TimeInterval = 3600
        func shouldFire(_ id: String) -> Bool {
            if let last = state.alerts.lastTriggeredAtById[id], now.timeIntervalSince(last) < cooldown {
                return false
            }
            state.alerts.lastTriggeredAtById[id] = now
            return true
        }
        
        for resource in content.pack.resources {
            let amount = state.resources[resource.id]?.amount ?? 0
            let cap = derived.resourceCaps[resource.id, default: 0]
            if cap > 0, amount >= cap * 0.9 {
                let alertId = "cap:\(resource.id)"
                if shouldFire(alertId) {
                    postToast(message: "\(resource.name) storage nearing cap", style: .warning)
                }
            }
        }
        
        for faction in state.factionStates.values {
            for contract in faction.activeContracts {
                if contract.remainingSeconds <= 7200 {
                    let alertId = "contract:\(contract.contractId)"
                    if shouldFire(alertId) {
                        if let def = content.contractsById[contract.contractId] {
                            postToast(message: "Contract expiring soon: \(def.name)", style: .info)
                        } else {
                            postToast(message: "Contract expiring soon", style: .info)
                        }
                    }
                }
            }
        }
        
        if derived.risk.raidChancePerHour > 0.15 {
            let alertId = "risk:raid"
            if shouldFire(alertId) {
                postToast(message: "Raid risk elevated. Consider defenses or pacts.", style: .warning)
            }
        }

        let cacheStored = state.collector.storedByResource.values.reduce(0, +)
        if cacheStored > 0 {
            let alertId = "collector:ready"
            if shouldFire(alertId) {
                postToast(message: "Resource cache ready to collect.", style: .info)
            }
        }
    }

    private func postToast(message: String, style: ToastStyle) {
        NotificationCenter.default.post(name: .clayToast, object: ToastPayload(message: message, style: style))
    }
    
    private func applyProjectProgress(seconds: Double) {
        guard !state.activeProjects.isEmpty else { return }
        var completed: [ProjectInstance] = []
        for index in state.activeProjects.indices {
            let project = state.activeProjects[index]
            let speed = projectSpeedMultiplier(for: project)
            state.activeProjects[index].remainingSeconds -= seconds * speed
            if state.activeProjects[index].remainingSeconds <= 0 {
                completed.append(state.activeProjects[index])
            }
        }
        if !completed.isEmpty {
            for project in completed {
                complete(project: project)
                state.activeProjects.removeAll { $0.id == project.id }
            }
        }
    }
    
    private func applyContractProgress(seconds: Double) {
        for (factionId, var faction) in state.factionStates {
            for index in faction.activeContracts.indices {
                faction.activeContracts[index].remainingSeconds -= seconds
                if let def = content.contractsById[faction.activeContracts[index].contractId] {
                    let upkeepMet = def.upkeepPerHour.keys.allSatisfy { resourceId in
                        (state.resources[resourceId]?.amount ?? 0) > 0
                    }
                    if !upkeepMet {
                        faction.activeContracts[index].upkeepMissed = true
                    }
                }
            }
            let expired = faction.activeContracts.filter { $0.remainingSeconds <= 0 }
            if !expired.isEmpty {
                faction.activeContracts.removeAll { $0.remainingSeconds <= 0 }
                let missed = expired.contains { $0.upkeepMissed }
                for contract in expired {
                    if contract.upkeepMissed,
                       let def = content.contractsById[contract.contractId],
                       !def.penaltyEffects.isEmpty {
                        applyEffects(def.penaltyEffects)
                    }
                }
                if missed {
                    faction.relationship = max(-2, faction.relationship - 1)
                } else {
                    faction.relationship = min(2, faction.relationship + 1)
                }
                state.factionStates[factionId] = faction
                addEvent(category: "contract", title: "Contract Completed", message: "A contract with \(factionId) concluded successfully.")
            } else {
                state.factionStates[factionId] = faction
            }
        }
    }

    private func applyDispatchProgress(seconds: Double, now: Date) {
        guard !state.dispatches.isEmpty else { return }
        for index in state.dispatches.indices {
            guard state.dispatches[index].status == .active else { continue }
            state.dispatches[index].remainingSeconds -= seconds
            if state.dispatches[index].remainingSeconds <= 0 {
                guard let def = content.dispatchesById[state.dispatches[index].dispatchId] else {
                    state.dispatches[index].status = .failed
                    continue
                }
                let roll = random(in: 0...1)
                state.dispatches[index].remainingSeconds = 0
                if roll < def.riskChance {
                    state.dispatches[index].status = .failed
                    addEvent(category: "dispatch", title: "Dispatch Failed", message: "\(def.name) returned with losses.")
                } else {
                    state.dispatches[index].status = .ready
                    addEvent(category: "dispatch", title: "Dispatch Ready", message: "\(def.name) is ready to collect.")
                }
            }
        }
    }

    private func updateCollectorStorage(produced: [String: Double], consumed: [String: Double], seconds: Double) {
        let hours = seconds / 3600.0
        guard hours > 0 else { return }
        for resource in content.pack.resources {
            let net = produced[resource.id, default: 0] - consumed[resource.id, default: 0]
            guard net > 0 else { continue }
            let rate = net / hours
            let maxStored = rate * state.collector.capacityHours
            let current = state.collector.storedByResource[resource.id, default: 0]
            let next = min(maxStored, current + net)
            state.collector.storedByResource[resource.id] = next
        }
        state.collector.lastUpdatedAt = Date()
    }

    private func evaluateAchievements(now: Date) {
        guard !content.pack.achievements.isEmpty else { return }
        var unlocked: [String] = state.achievementsUnlocked
        var changed = false
        for achievement in content.pack.achievements where !unlocked.contains(achievement.id) {
            if achievementMet(achievement, now: now) {
                unlocked.append(achievement.id)
                applyEffects(achievement.effects)
                addEvent(category: "achievement", title: "Achievement Unlocked", message: achievement.name)
                changed = true
            }
        }
        if changed {
            state.achievementsUnlocked = unlocked
        }
    }

    private func achievementMet(_ achievement: AchievementDefinition, now: Date) -> Bool {
        let condition = achievement.condition
        switch condition.type {
        case "resource_rate":
            guard let resourceId = condition.resourceId, let amount = condition.amount else { return false }
            let rate = computeResourceRatesPerHour()[resourceId, default: 0]
            return rate >= amount
        case "resource_total":
            guard let resourceId = condition.resourceId, let amount = condition.amount else { return false }
            let total = state.stats.totalProducedByResource[resourceId, default: 0]
            return total >= amount
        case "domain_tier":
            guard let domainId = condition.domainId, let tier = condition.tier else { return false }
            let unlocked = state.domainState.unlockedTiersByDomain[domainId, default: 0]
            return unlocked >= tier
        case "raid_free_days":
            guard let duration = condition.durationHours else { return false }
            let lastRaid = state.stats.lastRaidAt ?? state.lastSavedAt
            return now.timeIntervalSince(lastRaid) >= duration * 3600
        case "flag":
            guard let flagId = condition.flagId else { return false }
            return state.flags[flagId] == true
        default:
            return false
        }
    }
    
    private func applyResourceDelta(seconds: Double, start: Date, end: Date, policy: PolicyModifiers) {
        var produced: [String: Double] = [:]
        var consumed: [String: Double] = [:]
        var available: [String: Double] = [:]
        for (resourceId, resource) in state.resources {
            available[resourceId] = resource.amount
        }
        let caps = computeResourceCaps(policy: policy)
        var efficiencySum = 0.0
        var efficiencyCount = 0.0
        let logisticsFactor = state.logistics.logisticsFactor
        for building in state.buildings {
            guard let def = content.buildingsById[building.buildingId] else { continue }
            let activeSeconds = activeSecondsForBuilding(building, start: start, end: end)
            if activeSeconds <= 0 { continue }
            let secondsFactor = activeSeconds / 3600.0
            let levelMultiplier = pow(1.15, Double(building.level - 1))
                * adjacencyMultiplier(for: building, definition: def)
                * districtMultiplier(for: building, definition: def)
            var buildingProduction: [String: Double] = [:]
            var buildingConsumption: [String: Double] = [:]
            for (resource, amount) in def.productionPerHour {
                buildingProduction[resource, default: 0] += amount * levelMultiplier * secondsFactor
            }
            for (resource, amount) in def.consumptionPerHour {
                buildingConsumption[resource, default: 0] += amount * levelMultiplier * secondsFactor
            }
            for (resource, amount) in def.maintenancePerHour {
                buildingConsumption[resource, default: 0] += amount * secondsFactor
            }
            var inputFactor = 1.0
            for (resource, amount) in buildingConsumption where amount > 0 {
                let availableAmount = available[resource, default: 0]
                inputFactor = min(inputFactor, availableAmount / amount)
            }
            inputFactor = min(1.0, max(0.0, inputFactor))
            let baseFactor = min(1.0, inputFactor) * logisticsFactor
            let hasInputs = !buildingConsumption.isEmpty
            let productionFactor: Double
            if hasInputs {
                productionFactor = baseFactor
            } else {
                productionFactor = max(def.efficiencyFloor, baseFactor)
            }
            for (resource, amount) in buildingProduction {
                produced[resource, default: 0] += amount * productionFactor
            }
            for (resource, amount) in buildingConsumption {
                let total = amount * baseFactor
                consumed[resource, default: 0] += total
                available[resource, default: 0] = max(0, available[resource, default: 0] - total)
            }
            efficiencySum += baseFactor
            efficiencyCount += 1
        }
        var contractMultipliers: [String: Double] = [:]
        for (_, faction) in state.factionStates {
            for contract in faction.activeContracts {
                guard let def = content.contractsById[contract.contractId] else { continue }
                let secondsFactor = seconds / 3600.0
                let priceIndex = state.market.priceIndexByResource
                for (resource, amount) in def.effectsPerHour {
                    let marketMultiplier = priceIndex[resource, default: 1.0] * def.priceIndexMultiplier
                    produced[resource, default: 0] += amount * secondsFactor * marketMultiplier
                }
                for (resource, amount) in def.upkeepPerHour {
                    consumed[resource, default: 0] += amount * secondsFactor
                }
                for (resource, multiplier) in def.multipliers {
                    contractMultipliers[resource, default: 1.0] *= multiplier
                }
            }
        }
        var productionMultipliers: [String: Double] = [:]
        for resource in content.pack.resources.map(\.id) {
            var multiplier = state.globalResourceMultiplier * policy.globalMultiplier
            multiplier *= state.resourceMultipliers[resource, default: 1.0]
            multiplier *= policy.resourceMultipliers[resource, default: 1.0]
            multiplier *= contractMultipliers[resource, default: 1.0]
            productionMultipliers[resource] = multiplier
        }
        for (resource, multiplier) in productionMultipliers {
            produced[resource, default: 0] *= multiplier
        }
        updateCollectorStorage(produced: produced, consumed: consumed, seconds: seconds)
        state.stats.lastEfficiency = efficiencyCount > 0 ? efficiencySum / Double(efficiencyCount) : 1.0
        for (resourceId, var resource) in state.resources {
            let cap = caps[resourceId, default: resource.cap]
            let startAmount = resource.amount
            let net = produced[resourceId, default: 0] - consumed[resourceId, default: 0]
            var nextAmount = startAmount + net
            let waste = max(0, nextAmount - cap)
            if nextAmount > cap {
                nextAmount = cap
            }
            if nextAmount < 0 {
                nextAmount = 0
            }
            resource.cap = cap
            resource.amount = nextAmount
            state.resources[resourceId] = resource
            if produced[resourceId, default: 0] > 0 {
                state.stats.totalProducedByResource[resourceId, default: 0] += produced[resourceId, default: 0]
            }
            if waste > 0 {
                state.stats.totalWastedByResource[resourceId, default: 0] += waste
            }
        }
    }

    private func activeSecondsForBuilding(_ building: BuildingInstance, start: Date, end: Date) -> Double {
        guard let disabledUntil = building.disabledUntil else {
            return end.timeIntervalSince(start)
        }
        if disabledUntil <= start {
            return end.timeIntervalSince(start)
        }
        if disabledUntil >= end {
            return 0
        }
        return end.timeIntervalSince(disabledUntil)
    }
    
    private func processEvents(seconds: Double, offline: Bool) {
        let maxEvents = offline ? 20 : 3
        var eventsGenerated = 0
        state.nextEventInSeconds -= seconds
        if state.eventChains.pendingEventChainId != nil {
            return
        }
        while state.nextEventInSeconds <= 0 && eventsGenerated < maxEvents {
            if !triggerEventChainIfAvailable() {
                generateRandomEvent()
            }
            eventsGenerated += 1
            state.nextEventInSeconds += Double.random(in: 4_800...12_000, using: &rng)
        }
        if offline && eventsGenerated >= maxEvents {
            addEvent(category: "system", title: "While You Were Away", message: "Multiple events occurred while you were offline. Check Intel for details.")
        }
    }

    private func triggerEventChainIfAvailable() -> Bool {
        let now = Date()
        let candidates = content.pack.eventChains.filter { chain in
            guard let cooldown = state.eventChains.cooldownsByChainId[chain.id] else {
                return eventChainTriggered(chain)
            }
            return cooldown <= now && eventChainTriggered(chain)
        }
        guard !candidates.isEmpty else { return false }
        let index = Int(random(in: 0...Double(candidates.count - 1)))
        let selected = candidates[min(index, candidates.count - 1)]
        state.eventChains.pendingEventChainId = selected.id
        if !selected.effects.isEmpty {
            applyEffects(selected.effects)
        }
        addEvent(category: "decision", title: selected.title, message: selected.description)
        return true
    }

    private func eventChainTriggered(_ chain: EventChainDefinition) -> Bool {
        if let uniqueFlag = chain.uniqueFlagId, state.flags[uniqueFlag] == true {
            return false
        }
        let trigger = chain.trigger
        if let minExposure = trigger.minExposure, state.risk.exposure < minExposure { return false }
        if let minSecurity = trigger.minSecurity, state.risk.security < minSecurity { return false }
        if let minHostility = trigger.minHostility, state.risk.hostility < minHostility { return false }
        if let resourceId = trigger.resourceAtCapId {
            guard let resource = state.resources[resourceId] else { return false }
            let cap = computeResourceCaps(policy: policyModifiers())[resourceId, default: resource.cap]
            if cap <= 0 || resource.amount < cap * 0.95 { return false }
        }
        if let eraId = trigger.requiresEraId,
           let requiredEra = content.erasById[eraId],
           let currentEra = content.erasById[state.eraId],
           currentEra.sortOrder < requiredEra.sortOrder {
            return false
        }
        if let contractId = trigger.requiresContractId {
            let hasContract = state.factionStates.values.contains { faction in
                faction.activeContracts.contains { $0.contractId == contractId }
            }
            if !hasContract { return false }
        }
        if let flag = trigger.requiresFlag, state.flags[flag] != true {
            return false
        }
        if let maxLogistics = trigger.requiresLogisticsBelow, state.logistics.logisticsFactor > maxLogistics {
            return false
        }
        return true
    }

    public func resolveEventChoice(chainId: String, choiceId: String) {
        guard let chain = content.eventChainsById[chainId] else { return }
        guard let choice = chain.choices.first(where: { $0.id == choiceId }) else { return }
        applyEffects(choice.effects)
        addEvent(category: "decision", title: chain.title, message: choice.description)
        state.eventChains.cooldownsByChainId[chainId] = Date().addingTimeInterval(chain.cooldownSeconds)
        if let uniqueFlag = chain.uniqueFlagId {
            state.flags[uniqueFlag] = true
        }
        if let nextId = choice.nextId, content.eventChainsById[nextId] != nil {
            state.eventChains.pendingEventChainId = nextId
        } else {
            state.eventChains.pendingEventChainId = nil
        }
    }

    public func debugTriggerMetahumanEncounter() {
        guard state.eventChains.pendingEventChainId == nil else { return }
        let candidates = content.pack.eventChains.filter { $0.id.hasPrefix("meta_") }
        guard !candidates.isEmpty else { return }
        let now = Date()
        let eligible = candidates.filter { chain in
            let cooldown = state.eventChains.cooldownsByChainId[chain.id] ?? .distantPast
            return cooldown <= now && eventChainTriggered(chain)
        }
        guard let selected = eligible.randomElement() ?? candidates.randomElement() else { return }
        state.eventChains.pendingEventChainId = selected.id
        if !selected.effects.isEmpty {
            applyEffects(selected.effects)
        }
        addEvent(category: "decision", title: selected.title, message: selected.description)
    }
    
    private func generateRandomEvent() {
        let eligible = content.pack.events
        guard !eligible.isEmpty else { return }
        let totalWeight = eligible.reduce(0) { $0 + $1.weight }
        let roll = Double.random(in: 0...totalWeight, using: &rng)
        var running = 0.0
        for event in eligible {
            running += event.weight
            if roll <= running {
                applyEvent(event)
                return
            }
        }
    }
    
    private func applyEvent(_ event: EventDefinition) {
        switch event.id {
        case "market_shock":
            state.market.priceIndexByResource["credits", default: 1.0] = max(0.6, state.market.priceIndexByResource["credits", default: 1.0] - 0.1)
            addEvent(category: "market", title: event.title, message: "Markets contract briefly. Credit indices reduced for a time.")
        case "diplomatic_pressure":
            adjustFaction(id: "raiders", delta: -1)
            addEvent(category: "diplomacy", title: event.title, message: "Hostility rises. Defensive readiness advised.")
        case "discovery":
            state.chronoShards += 1
            addEvent(category: "discovery", title: event.title, message: "A Chrono Shard has been recovered.")
        case "infrastructure_failure":
            if let building = state.buildings.randomElement() {
                disableBuilding(buildingId: building.id, forSeconds: 1800)
                addEvent(category: "infrastructure", title: event.title, message: "One facility is temporarily offline.")
            }
        case "raid":
            resolveRaid()
        default:
            addEvent(category: event.category, title: event.title, message: event.description)
        }
    }
    
    private func resolveRaid() {
        let risk = computeRiskState(policy: policyModifiers())
        if risk.raidChancePerHour < 0.02 {
            addEvent(category: "raid", title: "Raid Averted", message: "Security posture deterred an attempted raid.")
            return
        }
        state.stats.lastRaidAt = Date()
        var stolenTotal = 0.0
        for (resourceId, var resource) in state.resources {
            let theft = resource.amount * 0.08 * (1.0 - min(0.7, risk.security))
            resource.amount = max(0, resource.amount - theft)
            stolenTotal += theft
            state.resources[resourceId] = resource
            state.stats.totalRaidLossByResource[resourceId, default: 0] += theft
        }
        addEvent(category: "raid", title: "Raid", message: "Raiders breached outer stores. Estimated losses: \(Int(stolenTotal)).")
    }
    
    private func disableBuilding(buildingId: UUID, forSeconds: Double) {
        guard let index = state.buildings.firstIndex(where: { $0.id == buildingId }) else { return }
        state.buildings[index].disabledUntil = Date().addingTimeInterval(forSeconds)
    }
    
    private func addEvent(category: String, title: String, message: String, severity: Int = 1) {
        let entry = EventLogEntry(id: UUID(), timestamp: Date(), category: category, title: title, message: message, severity: severity)
        state.events.insert(entry, at: 0)
        if state.events.count > 200 {
            state.events.removeLast()
        }
    }
    
    private func adjustFaction(id: String, delta: Int) {
        guard var faction = state.factionStates[id] else { return }
        faction.relationship = max(-2, min(2, faction.relationship + delta))
        state.factionStates[id] = faction
    }
    
    private func projectSpeedMultiplier(for project: ProjectInstance) -> Double {
        var multiplier = computeProjectSpeedMultiplier()
        if let activeId = state.catalyst.activeProjectId,
           let until = state.catalyst.activeUntil,
           activeId == project.id,
           Date() < until {
            multiplier += 0.75
        }
        return max(0.1, multiplier)
    }
    
    private func computeProjectSpeedMultiplier() -> Double {
        let base = 1.0
        var bonus = state.projectSpeedMultiplier
        bonus += policyModifiers().projectSpeedBonus
        for building in state.buildings {
            if let def = content.buildingsById[building.buildingId] {
                bonus += def.projectSpeedBonus * Double(building.level)
            }
        }
        return base + bonus
    }
    
    private func computeResourceRatesPerHour() -> [String: Double] {
        var rates: [String: Double] = [:]
        let policy = policyModifiers()
        let logisticsFactor = state.logistics.logisticsFactor
        for building in state.buildings {
            guard let def = content.buildingsById[building.buildingId] else { continue }
            if let disabledUntil = building.disabledUntil, disabledUntil > Date() {
                continue
            }
            let levelMultiplier = pow(1.15, Double(building.level - 1))
                * adjacencyMultiplier(for: building, definition: def)
                * districtMultiplier(for: building, definition: def)
            for (resource, amount) in def.productionPerHour {
                rates[resource, default: 0] += amount * levelMultiplier * logisticsFactor
            }
            for (resource, amount) in def.consumptionPerHour {
                rates[resource, default: 0] -= amount * levelMultiplier * logisticsFactor
            }
            for (resource, amount) in def.maintenancePerHour {
                rates[resource, default: 0] -= amount
            }
        }
        var contractMultipliers: [String: Double] = [:]
        for (_, faction) in state.factionStates {
            for contract in faction.activeContracts {
                guard let def = content.contractsById[contract.contractId] else { continue }
                for (resource, amount) in def.effectsPerHour {
                    let marketMultiplier = state.market.priceIndexByResource[resource, default: 1.0] * def.priceIndexMultiplier
                    rates[resource, default: 0] += amount * marketMultiplier
                }
                for (resource, amount) in def.upkeepPerHour {
                    rates[resource, default: 0] -= amount
                }
                for (resource, multiplier) in def.multipliers {
                    contractMultipliers[resource, default: 1.0] *= multiplier
                }
            }
        }
        for (resource, multiplier) in contractMultipliers {
            if rates[resource] != nil {
                rates[resource]! *= multiplier
            }
        }
        for (resource, multiplier) in state.resourceMultipliers {
            if rates[resource] != nil {
                rates[resource]! *= multiplier
            }
        }
        for (resource, multiplier) in policy.resourceMultipliers {
            if rates[resource] != nil {
                rates[resource]! *= multiplier
            }
        }
        for (resourceId, _) in rates {
            rates[resourceId, default: 0] *= (state.globalResourceMultiplier * policy.globalMultiplier)
        }
        return rates
    }

    private func adjacencyMultiplier(for building: BuildingInstance, definition: BuildingDefinition) -> Double {
        guard let bonus = definition.adjacencyBonus else { return 1.0 }
        let neighbors = [
            (building.x + 1, building.y),
            (building.x - 1, building.y),
            (building.x, building.y + 1),
            (building.x, building.y - 1)
        ]
        for (x, y) in neighbors {
            if let neighbor = buildingAt(x: x, y: y),
               neighbor.buildingId == bonus.requiresBuildingId {
                return bonus.multiplier
            }
        }
        return 1.0
    }

    private func districtMultiplier(for building: BuildingInstance, definition: BuildingDefinition) -> Double {
        guard let tag = definition.districtTag, !tag.isEmpty else { return 1.0 }
        let neighbors = [
            (building.x + 1, building.y),
            (building.x - 1, building.y),
            (building.x, building.y + 1),
            (building.x, building.y - 1)
        ]
        var matches = 0
        for (x, y) in neighbors {
            if let neighbor = buildingAt(x: x, y: y),
               let neighborDef = content.buildingsById[neighbor.buildingId],
               neighborDef.districtTag == tag {
                matches += 1
            }
        }
        return matches >= 2 ? definition.districtBonus : 1.0
    }
    
    private func computeResourceCaps(policy: PolicyModifiers? = nil) -> [String: Double] {
        let policyModifiers = policy ?? policyModifiers()
        var caps: [String: Double] = [:]
        for resource in content.pack.resources {
            caps[resource.id] = resource.baseCap
        }
        for building in state.buildings {
            guard let def = content.buildingsById[building.buildingId] else { continue }
            let levelMultiplier = pow(1.12, Double(building.level - 1))
            for (resource, amount) in def.storageCapAdd {
                caps[resource, default: 0] += amount * levelMultiplier
            }
        }
        for (resource, amount) in state.storageAdditions {
            caps[resource, default: 0] += amount
        }
        for (resource, amount) in policyModifiers.storageAdditions {
            caps[resource, default: 0] += amount
        }
        return caps
    }
    
    private func computeLogisticsState(policy: PolicyModifiers) -> LogisticsState {
        let baseCapacity = 100.0
        var capacity = baseCapacity + state.logisticsBonus + policy.logisticsBonus
        var demand = 0.0
        for building in state.buildings {
            guard let def = content.buildingsById[building.buildingId] else { continue }
            let levelMultiplier = pow(1.1, Double(building.level - 1))
                * adjacencyMultiplier(for: building, definition: def)
                * districtMultiplier(for: building, definition: def)
            capacity += def.logisticsCapAdd * levelMultiplier
            let prod = def.productionPerHour.values.reduce(0, +) * levelMultiplier
            let cons = def.consumptionPerHour.values.reduce(0, +) * levelMultiplier
            demand += abs(prod) + abs(cons)
        }
        let factor = capacity <= 0 ? 1.0 : min(1.0, capacity / max(1.0, demand))
        return LogisticsState(logisticsCapacity: capacity, logisticsDemand: demand, logisticsFactor: factor)
    }

    private func scaleDelta(_ amounts: ResourceAmount, old: Double, new: Double) -> ResourceAmount {
        var result: ResourceAmount = [:]
        for (resource, amount) in amounts {
            let delta = amount * (new - old)
            if abs(delta) > 0.0001 {
                result[resource] = delta
            }
        }
        return result
    }

    private func computeRiskState(policy: PolicyModifiers) -> RiskState {
        let caps = computeResourceCaps(policy: policy)
        var exposure = 0.0
        var count = 0.0
        for (resourceId, resource) in state.resources {
            let cap = caps[resourceId, default: resource.cap]
            if cap > 0 {
                exposure += min(1.0, resource.amount / cap)
                count += 1.0
            }
        }
        exposure = count > 0 ? exposure / count : 0
        var security = 0.0
        for building in state.buildings {
            guard let def = content.buildingsById[building.buildingId] else { continue }
            security += def.defenseScore
        }
        for (_, faction) in state.factionStates {
            for contract in faction.activeContracts {
                guard let def = content.contractsById[contract.contractId] else { continue }
                security += def.securityBonus
            }
        }
        security += state.securityBonus + policy.securityBonus
        security = min(1.0, security / 100.0)
        let hostility = hostilityLevel()
        let baseRate = 0.3
        let value = (exposure - security) * hostility * 4.0
        let raidChance = (1.0 / (1.0 + exp(-value))) * baseRate
        return RiskState(exposure: exposure, security: security, hostility: hostility, raidChancePerHour: raidChance)
    }
    
    private func hostilityLevel() -> Double {
        let raiders = state.factionStates["raiders"]?.relationship ?? 0
        switch raiders {
        case -2: return 1.0
        case -1: return 0.7
        case 0: return 0.4
        case 1: return 0.2
        default: return 0.1
        }
    }
    
    public func startProject(projectId: String, source: ProjectSource) {
        guard let project = content.projectsById[projectId] else { return }
        if let family = content.pack.megaprojectFamilies.first(where: { $0.choices.contains(projectId) }) {
            if family.exclusive,
               let chosen = state.chosenMegaprojectFamily[family.familyId],
               chosen != projectId {
                return
            }
            state.chosenMegaprojectFamily[family.familyId] = projectId
        }
        guard availableCrewCount() >= project.crewRequired else { return }
        guard canAfford(costs: project.costs) else { return }
        spend(costs: project.costs)
        state.queuedProjects.removeAll { $0.projectId == projectId }
        let duration = project.durationSeconds / max(0.1, computeProjectSpeedMultiplier())
        let instance = ProjectInstance(
            id: UUID(),
            projectId: projectId,
            remainingSeconds: duration,
            totalSeconds: duration,
            crewRequired: project.crewRequired,
            startedAt: Date(),
            source: source,
            associatedBuildingId: nil
        )
        state.activeProjects.append(instance)
    }

    public func queueProject(projectId: String, source: ProjectSource) {
        guard let project = content.projectsById[projectId] else { return }
        if projectQueueBlockReason(project) != nil {
            return
        }
        let instance = QueuedProject(id: UUID(), projectId: projectId, queuedAt: Date(), source: source)
        state.queuedProjects.append(instance)
    }

    public func unqueueProject(id: UUID) {
        state.queuedProjects.removeAll { $0.id == id }
    }
    
    public func startBuilding(buildingId: String, at position: (Int, Int)) {
        guard let def = content.buildingsById[buildingId] else { return }
        guard availableCrewCount() >= 1 else { return }
        guard canAfford(costs: def.baseCost) else { return }
        spend(costs: def.baseCost)
        let duration = def.buildTimeSeconds / max(0.1, computeProjectSpeedMultiplier())
        let completionDate = Date().addingTimeInterval(duration)
        let instance = ProjectInstance(
            id: UUID(),
            projectId: "build:\(buildingId)",
            remainingSeconds: duration,
            totalSeconds: duration,
            crewRequired: 1,
            startedAt: Date(),
            source: .buildingConstruction,
            associatedBuildingId: UUID()
        )
        state.activeProjects.append(instance)
        let building = BuildingInstance(id: instance.associatedBuildingId ?? UUID(), buildingId: buildingId, level: 1, x: position.0, y: position.1, disabledUntil: completionDate)
        state.buildings.append(building)
        addEvent(category: "construction", title: "Construction Started", message: "\(def.name) is under construction.")
    }
    
    public func upgradeBuilding(_ building: BuildingInstance) {
        guard let def = content.buildingsById[building.buildingId] else { return }
        guard building.level < def.maxLevel else { return }
        guard availableCrewCount() >= 1 else { return }
        let cost = scaledCost(base: def.baseCost, growth: def.costGrowth, level: building.level + 1)
        guard canAfford(costs: cost) else { return }
        spend(costs: cost)
        let duration = def.buildTimeSeconds * pow(1.3, Double(building.level)) / max(0.1, computeProjectSpeedMultiplier())
        let instance = ProjectInstance(
            id: UUID(),
            projectId: "upgrade:\(building.buildingId)",
            remainingSeconds: duration,
            totalSeconds: duration,
            crewRequired: 1,
            startedAt: Date(),
            source: .buildingUpgrade,
            associatedBuildingId: building.id
        )
        state.activeProjects.append(instance)
        if let index = state.buildings.firstIndex(where: { $0.id == building.id }) {
            state.buildings[index].disabledUntil = Date().addingTimeInterval(duration)
        }
        addEvent(category: "construction", title: "Upgrade Started", message: "\(def.name) upgrade initiated.")
    }
    
    private func complete(project: ProjectInstance) {
        if project.projectId.hasPrefix("build:") {
            if let buildingId = project.associatedBuildingId,
               let index = state.buildings.firstIndex(where: { $0.id == buildingId }) {
                state.buildings[index].disabledUntil = nil
            }
            addEvent(category: "construction", title: "Construction Complete", message: "A facility is now operational.")
            return
        }
        if project.projectId.hasPrefix("upgrade:") {
            if let buildingId = project.associatedBuildingId,
               let index = state.buildings.firstIndex(where: { $0.id == buildingId }) {
                state.buildings[index].level += 1
                state.buildings[index].disabledUntil = nil
                addEvent(category: "construction", title: "Upgrade Complete", message: "A facility has been upgraded.")
            }
            return
        }
        guard let def = content.projectsById[project.projectId] else { return }
        applyEffects(def.effects)
        state.completedProjectIds.append(def.id)
        awardDomainPoints(for: def.tags)
        addEvent(category: "project", title: "Project Completed", message: def.name)
    }
    
    private func applyEffects(_ effects: [EffectDefinition]) {
        for effect in effects {
            switch effect.type {
            case "add_resource_cap":
                if let resourceId = effect.resourceId, let amount = effect.amount {
                    state.storageAdditions[resourceId, default: 0] += amount
                }
            case "add_resource_multiplier":
                if let resourceId = effect.resourceId, let multiplier = effect.multiplier {
                    state.resourceMultipliers[resourceId, default: 1.0] *= multiplier
                }
            case "add_global_multiplier":
                if let multiplier = effect.multiplier {
                    state.globalResourceMultiplier *= multiplier
                }
            case "unlock_building":
                if let buildingId = effect.buildingId {
                    if !state.unlockedBuildingIds.contains(buildingId) {
                        state.unlockedBuildingIds.append(buildingId)
                    }
                }
            case "grant_resource":
                if let resourceId = effect.resourceId, let amount = effect.amount, var resource = state.resources[resourceId] {
                    resource.amount = max(0, resource.amount + amount)
                    state.resources[resourceId] = resource
                }
            case "adjust_faction":
                if let factionId = effect.factionId, let amount = effect.amount {
                    adjustFaction(id: factionId, delta: Int(amount))
                }
            case "unlock_project":
                if let projectId = effect.projectId {
                    if !state.unlockedProjectIds.contains(projectId) {
                        state.unlockedProjectIds.append(projectId)
                    }
                }
            case "unlock_era":
                if let eraId = effect.eraId, let era = content.erasById[eraId] {
                    state.eraId = eraId
                    for buildingId in era.unlocksBuildingIds {
                        if !state.unlockedBuildingIds.contains(buildingId) {
                            state.unlockedBuildingIds.append(buildingId)
                        }
                    }
                    for projectId in era.unlocksProjectIds {
                        if !state.unlockedProjectIds.contains(projectId) {
                            state.unlockedProjectIds.append(projectId)
                        }
                    }
                    state.gridSize += 10
                    addEvent(category: "era", title: "Era Advanced", message: "Entered \(era.name) era.")
                }
            case "add_crew":
                if let count = effect.crewCount {
                    state.crewCount += count
                    state.maxCrew = max(state.maxCrew, state.crewCount)
                }
            case "project_speed_bonus":
                if let amount = effect.amount {
                    state.projectSpeedMultiplier += amount
                }
            case "add_security_bonus":
                if let amount = effect.amount {
                    state.securityBonus += amount
                }
            case "add_logistics_cap":
                if let amount = effect.amount {
                    state.logisticsBonus += amount
                }
            case "add_offline_cap":
                if let amount = effect.amount {
                    state.settings.offlineCapDays += Int(amount)
                }
            case "unlock_catalyst":
                state.catalyst.availableAt = Date()
            case "grant_chrono_shards":
                if let amount = effect.amount {
                    state.chronoShards += Int(amount)
                }
            case "unlock_contract":
                if let contractId = effect.contractId {
                    state.flags["contract:\(contractId)"] = true
                }
            case "set_flag":
                if let flagId = effect.flagId {
                    state.flags[flagId] = true
                }
            case "adjust_metahuman_affinity":
                if let metaId = effect.metahumanId, let amount = effect.amount {
                    var metaState = state.metahumans[metaId] ?? MetahumanState(affinity: 0, disposition: .neutral, lastEncounterAt: nil)
                    let previousDisposition = metaState.disposition
                    metaState.affinity = max(-3, min(3, metaState.affinity + Int(amount)))
                    metaState.lastEncounterAt = Date()
                    if metaState.affinity >= 2 {
                        metaState.disposition = .ally
                    } else if metaState.affinity <= -2 {
                        metaState.disposition = .enemy
                    } else {
                        metaState.disposition = .neutral
                    }
                    state.metahumans[metaId] = metaState
                    let allyFlag = "metahuman:\(metaId):ally"
                    let enemyFlag = "metahuman:\(metaId):enemy"
                    state.flags[allyFlag] = metaState.disposition == .ally
                    state.flags[enemyFlag] = metaState.disposition == .enemy
                    if previousDisposition != metaState.disposition,
                       let meta = content.metahumansById[metaId] {
                        switch metaState.disposition {
                        case .ally:
                            addEvent(category: "metahuman", title: "Metahuman Allied", message: "\(meta.name) is now supporting your cause.")
                        case .enemy:
                            addEvent(category: "metahuman", title: "Metahuman Hostile", message: "\(meta.name) has turned against you.")
                        case .neutral:
                            addEvent(category: "metahuman", title: "Metahuman Neutral", message: "\(meta.name) is now undecided.")
                        }
                    }
                }
            default:
                break
            }
        }
    }

    private func awardDomainPoints(for tags: [String]) {
        guard !tags.isEmpty else { return }
        let tagSet = Set(tags)
        for domain in content.pack.domains {
            guard !tagSet.isDisjoint(with: Set(domain.tags)) else { continue }
            state.domainState.pointsByDomain[domain.id, default: 0] += 1
            unlockDomainTiers(for: domain)
        }
    }

    private func unlockDomainTiers(for domain: DomainDefinition) {
        let points = state.domainState.pointsByDomain[domain.id, default: 0]
        let currentTier = state.domainState.unlockedTiersByDomain[domain.id, default: 0]
        let sortedTiers = domain.tiers.sorted { $0.tier < $1.tier }
        var newTier = currentTier
        for tier in sortedTiers where tier.tier > currentTier && points >= tier.requiredPoints {
            applyEffects(tier.effects)
            newTier = max(newTier, tier.tier)
            addEvent(category: "domain", title: "Domain Tier Unlocked", message: "\(domain.name) Tier \(tier.tier) achieved.")
        }
        if newTier != currentTier {
            state.domainState.unlockedTiersByDomain[domain.id] = newTier
        }
    }
    
    public func activateCatalyst(for projectId: UUID) {
        guard Date() >= state.catalyst.availableAt else { return }
        let boostDuration = 3600.0
        state.catalyst.activeProjectId = projectId
        state.catalyst.activeUntil = Date().addingTimeInterval(boostDuration)
        state.catalyst.availableAt = Date().addingTimeInterval(86_400.0 - Double(state.catalyst.level) * 3_600.0)
    }
    
    public func useChronoShard(on projectId: UUID) {
        guard state.chronoShards > 0 else { return }
        guard let index = state.activeProjects.firstIndex(where: { $0.id == projectId }) else { return }
        state.activeProjects[index].remainingSeconds = max(0, state.activeProjects[index].remainingSeconds - 3600)
        state.chronoShards -= 1
    }
    
    public func startContract(_ contract: ContractDefinition) {
        guard var faction = state.factionStates[contract.factionId] else { return }
        guard faction.relationship >= contract.requiredRelationship else { return }
        guard !faction.activeContracts.contains(where: { $0.contractId == contract.id }) else { return }
        let instance = ContractInstance(id: UUID(), contractId: contract.id, factionId: contract.factionId, remainingSeconds: contract.durationSeconds, upkeepMissed: false)
        faction.activeContracts.append(instance)
        state.factionStates[contract.factionId] = faction
        addEvent(category: "contract", title: "Contract Initiated", message: contract.name)
    }

    public func dispatchBlockReason(_ dispatch: DispatchDefinition) -> String? {
        guard let requiredEra = content.erasById[dispatch.era],
              let currentEra = content.erasById[state.eraId] else {
            return "Dispatch locked"
        }
        if currentEra.sortOrder < requiredEra.sortOrder {
            return "Dispatch locked"
        }
        if availableCrewCount() < dispatch.requiredCrew {
            return "No available crews"
        }
        if state.dispatches.contains(where: { $0.dispatchId == dispatch.id }) {
            return "Dispatch already active"
        }
        return nil
    }

    public func startDispatch(dispatchId: String) {
        guard let dispatch = content.dispatchesById[dispatchId] else { return }
        if dispatchBlockReason(dispatch) != nil {
            return
        }
        let instance = DispatchInstance(
            id: UUID(),
            dispatchId: dispatchId,
            remainingSeconds: dispatch.durationSeconds,
            startedAt: Date(),
            status: .active
        )
        state.dispatches.append(instance)
        addEvent(category: "dispatch", title: "Dispatch Started", message: dispatch.name)
    }

    public func collectDispatch(id: UUID) {
        guard let index = state.dispatches.firstIndex(where: { $0.id == id }) else { return }
        let instance = state.dispatches[index]
        guard let def = content.dispatchesById[instance.dispatchId] else { return }
        if instance.status == .ready || instance.status == .failed {
            let rewardMultiplier = instance.status == .failed ? 0.5 : 1.0
            for (resourceId, amount) in def.rewards {
                if var resource = state.resources[resourceId] {
                    let cap = computeResourceCaps(policy: policyModifiers())[resourceId, default: resource.cap]
                    let gained = amount * rewardMultiplier
                    resource.amount = min(cap, resource.amount + gained)
                    state.resources[resourceId] = resource
                    state.stats.totalProducedByResource[resourceId, default: 0] += gained
                    state.stats.dispatchRewardsByResource[resourceId, default: 0] += gained
                }
            }
            if instance.status == .ready {
                state.stats.dispatchesCompleted += 1
            }
            addEvent(category: "dispatch", title: "Dispatch Collected", message: def.name)
            state.dispatches.remove(at: index)
        }
    }

    public func collectCache() {
        let policy = policyModifiers()
        let caps = computeResourceCaps(policy: policy)
        var collectedAny = false
        for (resourceId, stored) in state.collector.storedByResource {
            guard stored > 0 else { continue }
            if var resource = state.resources[resourceId] {
                let cap = caps[resourceId, default: resource.cap]
                let nextAmount = min(cap, resource.amount + stored)
                let waste = max(0, resource.amount + stored - cap)
                resource.amount = nextAmount
                state.resources[resourceId] = resource
                if waste > 0 {
                    state.stats.totalWastedByResource[resourceId, default: 0] += waste
                }
                collectedAny = true
            }
        }
        if collectedAny {
            state.collector.lastCollectedAt = Date()
            for key in state.collector.storedByResource.keys {
                state.collector.storedByResource[key] = 0
            }
            addEvent(category: "system", title: "Cache Collected", message: "Resource cache transferred to storage.")
        }
    }
    
    private func canAfford(costs: ResourceAmount) -> Bool {
        for (resourceId, cost) in costs {
            if (state.resources[resourceId]?.amount ?? 0) < cost {
                return false
            }
        }
        return true
    }

    public func canAffordPublic(costs: ResourceAmount) -> Bool {
        canAfford(costs: costs)
    }
    
    private func spend(costs: ResourceAmount) {
        for (resourceId, cost) in costs {
            if var resource = state.resources[resourceId] {
                resource.amount = max(0, resource.amount - cost)
                state.resources[resourceId] = resource
            }
        }
    }
    
    private func scaledCost(base: ResourceAmount, growth: Double, level: Int) -> ResourceAmount {
        var result: ResourceAmount = [:]
        let multiplier = pow(growth, Double(level - 1))
        for (resource, amount) in base {
            result[resource] = amount * multiplier
        }
        return result
    }
    
    public func availableCrewCount() -> Int {
        let usedProjects = state.activeProjects.reduce(0) { $0 + $1.crewRequired }
        let usedDispatches = state.dispatches.reduce(0) { total, dispatch in
            guard dispatch.status == .active,
                  let def = content.dispatchesById[dispatch.dispatchId] else { return total }
            return total + def.requiredCrew
        }
        return max(0, state.crewCount - usedProjects - usedDispatches)
    }
    
    public func gridOccupied(x: Int, y: Int) -> Bool {
        state.buildings.contains { $0.x == x && $0.y == y }
    }
    
    public func buildingAt(x: Int, y: Int) -> BuildingInstance? {
        state.buildings.first { $0.x == x && $0.y == y }
    }
    
    public func computeResourceRatesPerHourPublic() -> [String: Double] {
        computeResourceRatesPerHour()
    }
    
    public func computeResourceCapsPublic() -> [String: Double] {
        computeResourceCaps()
    }

    public func simulate(seconds: Double, now: Date? = nil, isOffline: Bool = true) {
        let next = now ?? state.lastTickAt.addingTimeInterval(seconds)
        advance(by: seconds, now: next, isOffline: isOffline)
    }

    func debugSetResource(_ id: String, amount: Double, cap: Double? = nil) {
        if var resource = state.resources[id] {
            resource.amount = amount
            if let cap {
                resource.cap = cap
            }
            state.resources[id] = resource
        }
    }

    func debugAddBuilding(buildingId: String, x: Int, y: Int, level: Int = 1) {
        let building = BuildingInstance(id: UUID(), buildingId: buildingId, level: level, x: x, y: y, disabledUntil: nil)
        state.buildings.append(building)
    }

    func debugSetNextEventInSeconds(_ value: Double) {
        state.nextEventInSeconds = value
    }

    func debugSetFactionRelationship(_ id: String, value: Int) {
        if var faction = state.factionStates[id] {
            faction.relationship = value
            state.factionStates[id] = faction
        }
    }

    func debugSetFlag(_ id: String, value: Bool) {
        state.flags[id] = value
    }

    func debugCompleteProject(_ id: String) {
        if !state.completedProjectIds.contains(id) {
            state.completedProjectIds.append(id)
        }
    }

    func debugSetTotalProduced(resourceId: String, amount: Double) {
        state.stats.totalProducedByResource[resourceId] = amount
    }

    func debugSetContractRemaining(contractId: String, seconds: Double) {
        for (factionId, var faction) in state.factionStates {
            for index in faction.activeContracts.indices {
                if faction.activeContracts[index].contractId == contractId {
                    faction.activeContracts[index].remainingSeconds = seconds
                }
            }
            state.factionStates[factionId] = faction
        }
    }

    func debugUnlockProject(_ id: String) {
        if !state.unlockedProjectIds.contains(id) {
            state.unlockedProjectIds.append(id)
        }
    }

    func debugAddDomainPoints(domainId: String, amount: Int) {
        state.domainState.pointsByDomain[domainId, default: 0] += amount
        if let domain = content.domainsById[domainId] {
            unlockDomainTiers(for: domain)
        }
    }

    func debugSetCollectorStored(resourceId: String, amount: Double) {
        state.collector.storedByResource[resourceId] = amount
    }
    
    private static func defaultState(content: ContentCatalog) -> GameState {
        var resources: [String: ResourceState] = [:]
        for resource in content.pack.resources {
            resources[resource.id] = ResourceState(amount: resource.startingAmount, cap: resource.baseCap)
        }
        var unlockedBuildings: [String] = []
        var unlockedProjects: [String] = []
        if let era = content.pack.eras.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
            unlockedBuildings = era.unlocksBuildingIds
            unlockedProjects = era.unlocksProjectIds
        }
        var factionStates: [String: FactionState] = [:]
        for faction in content.pack.factions {
            let baseRelationship = faction.id == "raiders" ? -1 : 0
            factionStates[faction.id] = FactionState(relationship: baseRelationship, activeContracts: [])
        }
        let now = Date()
        let stats = StatsState(
            totalProducedByResource: content.pack.resources.reduce(into: [:]) { $0[$1.id] = 0 },
            totalWastedByResource: content.pack.resources.reduce(into: [:]) { $0[$1.id] = 0 },
            totalRaidLossByResource: content.pack.resources.reduce(into: [:]) { $0[$1.id] = 0 },
            lastEfficiency: 1.0,
            lastRaidAt: now,
            dispatchesCompleted: 0,
            dispatchRewardsByResource: [:]
        )
        let metahumans = content.pack.metahumans.reduce(into: [:]) { result, meta in
            result[meta.id] = MetahumanState(affinity: 0, disposition: .neutral, lastEncounterAt: nil)
        }
        return GameState(
            saveVersion: GameState.currentVersion,
            lastSavedAt: now,
            lastTickAt: now,
            resources: resources,
            unlockedBuildingIds: unlockedBuildings,
            unlockedProjectIds: unlockedProjects,
            completedProjectIds: [],
            activeProjects: [],
            queuedProjects: [],
            crewCount: 2,
            maxCrew: 2,
            eraId: "stone",
            flags: [:],
            buildings: [],
            factionStates: factionStates,
            events: [],
            catalyst: CatalystState(availableAt: Date.distantFuture, activeProjectId: nil, activeUntil: nil, level: 0),
            chronoShards: 0,
            projectSpeedMultiplier: 0,
            resourceMultipliers: [:],
            globalResourceMultiplier: 1.0,
            storageAdditions: [:],
            securityBonus: 0,
            logisticsBonus: 0,
            risk: RiskState(exposure: 0, security: 0, hostility: 0.4, raidChancePerHour: 0),
            market: MarketState(priceIndexByResource: content.pack.resources.reduce(into: [:]) { $0[$1.id] = 1.0 }, lastUpdatedAt: now),
            logistics: LogisticsState(logisticsCapacity: 100, logisticsDemand: 0, logisticsFactor: 1),
            policyState: PolicyState(activePoliciesBySlot: [:], cooldownsByPolicyId: [:]),
            domainState: DomainState(pointsByDomain: content.pack.domains.reduce(into: [:]) { $0[$1.id] = 0 }, unlockedTiersByDomain: content.pack.domains.reduce(into: [:]) { $0[$1.id] = 0 }),
            dispatches: [],
            collector: CollectorState(storedByResource: content.pack.resources.reduce(into: [:]) { $0[$1.id] = 0 }, capacityHours: content.pack.collector.capacityHours, lastCollectedAt: now, lastUpdatedAt: now),
            chosenMegaprojectFamily: [:],
            achievementsUnlocked: [],
            autoPlanRules: AutoPlanRules(enabled: false, priorityTags: [], autoRenewContracts: false),
            prestige: PrestigeState(legacyPoints: 0, legacyUpgrades: [], lastPrestigeAt: nil),
            stats: stats,
            metahumans: metahumans,
            people: PeopleState(recruitedIds: [], maxRoster: 8),
            eventChains: EventChainState(pendingEventChainId: nil, cooldownsByChainId: [:]),
            alerts: AlertState(lastTriggeredAtById: [:]),
            nextEventInSeconds: Double.random(in: 5_000...12_000),
            gridSize: 20,
            pendingTimeTravelWarning: false,
            timeTravelClampUntil: nil,
            settings: SettingsState(offlineCapDays: 7, notificationsEnabled: true, colorblindMode: false, use3DPreviews: true)
        )
    }
    
    private static func computeDerived(state: GameState, content: ContentCatalog) -> DerivedState {
        var caps: [String: Double] = [:]
        for resource in content.pack.resources {
            caps[resource.id] = resource.baseCap
        }
        var rates: [String: Double] = [:]
        for building in state.buildings {
            guard let def = content.buildingsById[building.buildingId] else { continue }
            let levelMultiplier = pow(1.15, Double(building.level - 1)) * (def.adjacencyBonus == nil ? 1.0 : 1.0)
            for (resource, amount) in def.productionPerHour {
                rates[resource, default: 0] += amount * levelMultiplier * state.logistics.logisticsFactor
            }
            for (resource, amount) in def.consumptionPerHour {
                rates[resource, default: 0] -= amount * levelMultiplier * state.logistics.logisticsFactor
            }
            for (resource, amount) in def.maintenancePerHour {
                rates[resource, default: 0] -= amount
            }
            for (resource, amount) in def.storageCapAdd {
                caps[resource, default: 0] += amount * levelMultiplier
            }
        }
        for (resource, amount) in state.storageAdditions {
            caps[resource, default: 0] += amount
        }
        for (resource, multiplier) in state.resourceMultipliers {
            if rates[resource] != nil {
                rates[resource]! *= multiplier
            }
        }
        for (resourceId, _) in rates {
            rates[resourceId, default: 0] *= state.globalResourceMultiplier
        }
        var timeToCap: [String: Double?] = [:]
        for (resourceId, resource) in state.resources {
            let cap = caps[resourceId, default: resource.cap]
            let rate = rates[resourceId, default: 0]
            if rate > 0 {
                timeToCap[resourceId] = max(0, (cap - resource.amount) / rate)
            } else {
                timeToCap[resourceId] = nil
            }
        }
        let usedProjects = state.activeProjects.reduce(0) { $0 + $1.crewRequired }
        let usedDispatches = state.dispatches.reduce(0) { total, dispatch in
            guard dispatch.status == .active,
                  let def = content.dispatchesById[dispatch.dispatchId] else { return total }
            return total + def.requiredCrew
        }
        let usedCrew = usedProjects + usedDispatches
        let available = max(0, state.crewCount - usedCrew)
        let risk = state.risk
        return DerivedState(
            resourceRatesPerHour: rates,
            resourceCaps: caps,
            timeToCapHours: timeToCap,
            activeCrewCount: usedCrew,
            availableCrewCount: available,
            projectSpeedMultiplier: 1.0 + state.projectSpeedMultiplier,
            risk: risk,
            logistics: state.logistics,
            averageEfficiency: state.stats.lastEfficiency,
            marketIndexByResource: state.market.priceIndexByResource
        )
    }
}
