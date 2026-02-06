import Testing
import Foundation
@testable import ClayFeature

@Test @MainActor func stellarEraCompletionAllowsAnyTypeII() {
    let engine = GameEngine(seed: 101, shouldStartTimers: false, loadPersistence: false)
    guard let stellar = engine.content.erasById["stellar"] else {
        #expect(Bool(false))
        return
    }
    #expect(engine.isEraComplete(stellar) == false)
    engine.debugCompleteProject("type_ii_matrioshka_brain")
    #expect(engine.isEraComplete(stellar) == true)
}

@Test @MainActor func worldStateClampsAndAffectsFoodOutput() {
    let engine = GameEngine(seed: 102, shouldStartTimers: false, loadPersistence: false)
    guard engine.content.buildingsById["foraging_hut"] != nil else {
        #expect(Bool(false))
        return
    }
    engine.debugAddBuilding(buildingId: "foraging_hut", x: 0, y: 0)

    engine.debugUpdateState { state in
        state.cohesion = 0.0
        state.biosphere = 0.0
    }
    let lowFood = engine.computeResourceRatesPerHourPublic()["food", default: 0]

    engine.debugUpdateState { state in
        state.cohesion = 1.0
        state.biosphere = 1.0
    }
    let highFood = engine.computeResourceRatesPerHourPublic()["food", default: 0]
    #expect(highFood > lowFood)

    let past = Date().addingTimeInterval(-3600)
    engine.debugUpdateState { state in
        state.cohesion = 1.2
        state.biosphere = 1.3
        state.lastSavedAt = past
        state.lastTickAt = past
    }
    engine.reconcileOffline(now: Date())
    #expect(engine.state.cohesion <= 1.0)
    #expect(engine.state.biosphere <= 1.0)
}

@Test @MainActor func migrationPromotesTypeIIToGalacticEra() {
    let engine = GameEngine(seed: 103, shouldStartTimers: false, loadPersistence: false)
    engine.debugUpdateState { state in
        state.saveVersion = 6
        state.eraId = "planetary"
        state.flags["type_ii_complete"] = true
    }
    engine.debugRunMigration()
    #expect(engine.state.eraId == "galactic")
    #expect(engine.state.unlockedBuildingIds.contains("galactic_archive"))
}
