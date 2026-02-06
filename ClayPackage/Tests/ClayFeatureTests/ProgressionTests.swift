import Testing
import Foundation
@testable import ClayFeature

@Test @MainActor func domainTierReachabilityUnlocks() {
    let engine = GameEngine(seed: 21, shouldStartTimers: false, loadPersistence: false)
    engine.debugAddDomainPoints(domainId: "diplomacy", amount: 2)
    #expect(engine.state.domainState.unlockedTiersByDomain["diplomacy"] == 1)
    engine.debugAddDomainPoints(domainId: "diplomacy", amount: 2)
    #expect(engine.state.domainState.unlockedTiersByDomain["diplomacy"] == 2)
    engine.debugAddDomainPoints(domainId: "diplomacy", amount: 3)
    #expect(engine.state.domainState.unlockedTiersByDomain["diplomacy"] == 3)
}

@Test @MainActor func lockedProjectBlocksStart() {
    let engine = GameEngine(seed: 22, shouldStartTimers: false, loadPersistence: false)
    guard let project = engine.content.projectsById["basic_literacy"] else {
        #expect(Bool(false))
        return
    }
    #expect(engine.projectBlockReason(project) == "Project locked")
    for (resourceId, _) in project.costs {
        engine.debugSetResource(resourceId, amount: 10_000)
    }
    engine.startProject(projectId: project.id, source: .research)
    #expect(engine.state.activeProjects.isEmpty)
}

@Test @MainActor func legacyGainBreakdownTotals() {
    let engine = GameEngine(seed: 23, shouldStartTimers: false, loadPersistence: false)
    engine.debugCompleteProject("keystone_agricultural_network")
    engine.debugCompleteProject("keystone_foundry_standardization")
    engine.debugCompleteProject("keystone_industrial_power_grid")

    engine.debugUpdateState { state in
        var domainState = state.domainState
        domainState.unlockedTiersByDomain["industry"] = 2
        domainState.unlockedTiersByDomain["science"] = 1
        domainState.unlockedTiersByDomain["diplomacy"] = 0
        domainState.unlockedTiersByDomain["infrastructure"] = 3
        state.domainState = domainState

        state.achievementsUnlocked = [
            "ach_energy_surge",
            "ach_type_ii",
            "ach_food_surplus",
            "ach_materials_flow",
            "ach_infrastructure_tier1"
        ]
        state.flags["type_iii_complete"] = true
        var stats = state.stats
        stats.totalProducedByResource["energy"] = 1_000_000_000
        state.stats = stats
    }

    let breakdown = engine.legacyGainBreakdown()
    #expect(breakdown.eraPoints == 3)
    #expect(breakdown.domainBonus == 2)
    #expect(breakdown.achievementBonus == 1)
    #expect(breakdown.energyBonus == 2)
    #expect(breakdown.total == 8)
}
