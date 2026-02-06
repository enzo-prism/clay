import Testing
import Foundation
@testable import ClayFeature

@Test @MainActor func inputThrottlingStopsProductionWithoutInputs() {
    let engine = GameEngine(seed: 1, shouldStartTimers: false, loadPersistence: false)
    engine.debugSetResource("food", amount: 0)
    engine.debugSetResource("credits", amount: 0)
    engine.debugAddBuilding(buildingId: "trade_post", x: 0, y: 0)
    engine.simulate(seconds: 3600)
    let credits = engine.state.resources["credits"]?.amount ?? 0
    #expect(credits < 0.01)
}

@Test @MainActor func inputThrottlingScalesWithPartialInputs() {
    let engine = GameEngine(seed: 2, shouldStartTimers: false, loadPersistence: false)
    engine.debugSetResource("food", amount: 1)
    engine.debugSetResource("credits", amount: 0)
    engine.debugAddBuilding(buildingId: "trade_post", x: 0, y: 0)
    engine.simulate(seconds: 3600)
    let credits = engine.state.resources["credits"]?.amount ?? 0
    #expect(credits > 1.2 && credits < 1.8)
}

@Test @MainActor func logisticsFactorDropsWithHighDemand() {
    let engine = GameEngine(seed: 3, shouldStartTimers: false, loadPersistence: false)
    for i in 0..<200 {
        engine.debugAddBuilding(buildingId: "foraging_hut", x: i % 20, y: i / 20)
    }
    engine.simulate(seconds: 1)
    #expect(engine.state.logistics.logisticsFactor < 0.2)
}

@Test @MainActor func policyCooldownPreventsImmediateReapply() {
    let engine = GameEngine(seed: 4, shouldStartTimers: false, loadPersistence: false)
    engine.setPolicy(slot: "economy", policyId: "policy_austerity")
    let first = engine.state.policyState.activePoliciesBySlot["economy"]
    engine.setPolicy(slot: "economy", policyId: "policy_austerity")
    let second = engine.state.policyState.activePoliciesBySlot["economy"]
    #expect(first == second)
}

@Test @MainActor func eventChainTriggersAndChoiceApplies() {
    let engine = GameEngine(seed: 5, shouldStartTimers: false, loadPersistence: false)
    engine.resolveEventChoice(chainId: "logistics_bottleneck", choiceId: "expand_hubs")
    #expect(engine.state.logisticsBonus >= 100)
}

@Test @MainActor func prestigeResetKeepsLegacy() {
    let engine = GameEngine(seed: 6, shouldStartTimers: false, loadPersistence: false)
    if let era = engine.content.pack.eras.first(where: { $0.sortOrder == 1 }) {
        engine.debugCompleteProject(era.keystoneProjectId)
    }
    engine.debugSetFlag("type_iii_complete", value: true)
    engine.debugSetTotalProduced(resourceId: "energy", amount: 1_000_000_000)
    let gain = engine.availableLegacyGain()
    #expect(gain > 0)
    engine.ascend()
    #expect(engine.state.prestige.legacyPoints >= gain)
    #expect(engine.state.eraId == "stone")
}

@Test @MainActor func autoPlannerQueuesProjects() {
    let engine = GameEngine(seed: 7, shouldStartTimers: false, loadPersistence: false)
    for resource in engine.content.pack.resources {
        engine.debugSetResource(resource.id, amount: 10_000)
    }
    if let project = engine.content.pack.projects.first(where: { engine.state.unlockedProjectIds.contains($0.id) }),
       let tag = project.tags.first {
        engine.setAutoPlanTag(tag, enabled: true)
    }
    engine.setAutoPlannerEnabled(true)
    engine.simulate(seconds: 1, isOffline: false)
    #expect(!engine.state.activeProjects.isEmpty)
}

@Test @MainActor func autoRenewExtendsContracts() {
    let engine = GameEngine(seed: 8, shouldStartTimers: false, loadPersistence: false)
    guard let contract = engine.content.pack.contracts.first(where: { $0.renewable }) else {
        #expect(Bool(false))
        return
    }
    for resource in engine.content.pack.resources {
        engine.debugSetResource(resource.id, amount: 10_000)
    }
    engine.debugSetFactionRelationship(contract.factionId, value: max(0, contract.requiredRelationship))
    engine.startContract(contract)
    engine.debugSetContractRemaining(contractId: contract.id, seconds: 3000)
    engine.setAutoRenewContracts(true)
    engine.simulate(seconds: 1, isOffline: false)
    let remaining = engine.state.factionStates[contract.factionId]?.activeContracts.first?.remainingSeconds ?? 0
    #expect(remaining > contract.durationSeconds)
}

@Test @MainActor func assetMappingsExist() {
    let catalog = ContentLoader.load()
    let kenney = KenneyAssetCatalog.shared
    for building in catalog.pack.buildings {
        #expect(kenney.buildingAsset(for: building.id) != nil)
    }
    for resource in catalog.pack.resources {
        #expect(kenney.resourceIconPath(for: resource.id) != nil)
    }
}
