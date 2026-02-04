import Testing
import Foundation
@testable import ClayFeature

@Test @MainActor func domainTierUnlockAppliesEffects() {
    let engine = GameEngine(seed: 11, shouldStartTimers: false, loadPersistence: false)
    engine.debugAddDomainPoints(domainId: "industry", amount: 3)
    #expect(engine.state.domainState.unlockedTiersByDomain["industry"] == 1)
    let multiplier = engine.state.resourceMultipliers["materials", default: 1.0]
    #expect(multiplier > 1.0)
}

@Test @MainActor func dispatchCompletesAndCollectsRewards() {
    let engine = GameEngine(seed: 12, shouldStartTimers: false, loadPersistence: false)
    engine.debugSetResource("materials", amount: 0)
    engine.startDispatch(dispatchId: "dispatch_scavenging")
    engine.simulate(seconds: 8000)
    guard let dispatch = engine.state.dispatches.first else {
        #expect(Bool(false))
        return
    }
    #expect(dispatch.status != .active)
    engine.collectDispatch(id: dispatch.id)
    #expect(engine.state.dispatches.isEmpty)
    let materials = engine.state.resources["materials"]?.amount ?? 0
    #expect(materials > 0)
}

@Test @MainActor func collectorClampsAndTransfers() {
    let engine = GameEngine(seed: 13, shouldStartTimers: false, loadPersistence: false)
    engine.debugSetResource("food", amount: 0, cap: 10_000)
    engine.debugAddBuilding(buildingId: "foraging_hut", x: 0, y: 0)
    engine.simulate(seconds: 48 * 3600)
    let baseRate = engine.content.buildingsById["foraging_hut"]?.productionPerHour["food"] ?? 0
    let maxStored = baseRate * engine.state.collector.capacityHours
    let stored = engine.state.collector.storedByResource["food", default: 0]
    #expect(abs(stored - maxStored) < 0.1)
    engine.collectCache()
    #expect(engine.state.collector.storedByResource["food", default: 0] == 0)
    #expect(engine.state.resources["food"]?.amount ?? 0 > 0)
}

@Test @MainActor func megaprojectFamilyExclusiveBlocksOtherChoices() {
    let engine = GameEngine(seed: 14, shouldStartTimers: false, loadPersistence: false)
    engine.debugUnlockProject("keystone_stellar_collector_array")
    engine.debugUnlockProject("type_ii_matrioshka_brain")
    for resource in engine.content.pack.resources {
        engine.debugSetResource(resource.id, amount: 20_000)
    }
    engine.startProject(projectId: "keystone_stellar_collector_array", source: .megaproject)
    if let other = engine.content.projectsById["type_ii_matrioshka_brain"] {
        #expect(engine.projectBlockReason(other) != nil)
    } else {
        #expect(Bool(false))
    }
}

@Test @MainActor func achievementUnlocksOnFlag() {
    let engine = GameEngine(seed: 15, shouldStartTimers: false, loadPersistence: false)
    engine.debugSetFlag("type_ii_complete", value: true)
    engine.simulate(seconds: 1)
    #expect(engine.state.achievementsUnlocked.contains("ach_type_ii"))
}
