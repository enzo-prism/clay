import Testing
import Foundation
@testable import ClayFeature

@Test @MainActor func derivedMatchesPublicComputations() {
    let engine = GameEngine(seed: 101, shouldStartTimers: false, loadPersistence: false)
    engine.debugSetNextEventInSeconds(1_000_000_000)
    let allAchievements = engine.content.pack.achievements.map(\.id)

    let start = Date(timeIntervalSince1970: 1_700_000_000)
    engine.debugUpdateState { state in
        state.lastSavedAt = start
        state.lastTickAt = start
        state.market.lastUpdatedAt = start
        state.collector.lastUpdatedAt = start
        state.collector.lastCollectedAt = start
        state.nextEventInSeconds = 1_000_000_000
        state.achievementsUnlocked = allAchievements

        let resourceIds = Array(state.resources.keys)
        for resourceId in resourceIds {
            if var resource = state.resources[resourceId] {
                resource.amount = 100_000
                resource.cap = max(resource.cap, 200_000)
                state.resources[resourceId] = resource
            }
        }

        state.buildings = [
            BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, buildingId: "farm", level: 1, x: 0, y: 0, disabledUntil: nil),
            BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, buildingId: "irrigation_channel", level: 1, x: 1, y: 0, disabledUntil: nil),
            BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, buildingId: "generator", level: 1, x: 10, y: 10, disabledUntil: nil),
            BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, buildingId: "generator", level: 1, x: 11, y: 10, disabledUntil: nil),
            BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!, buildingId: "generator", level: 1, x: 10, y: 11, disabledUntil: nil),
            BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!, buildingId: "generator", level: 1, x: 11, y: 11, disabledUntil: nil)
        ]
    }

    engine.simulate(seconds: 1, now: start.addingTimeInterval(1), isOffline: true)

    let capsPublic = engine.computeResourceCapsPublic()
    for (resourceId, expectedCap) in capsPublic {
        let cap = engine.derived.resourceCaps[resourceId, default: 0]
        #expect(abs(cap - expectedCap) < 1e-9)
    }

    let ratesPublic = engine.computeResourceRatesPerHourPublic()
    for (resourceId, expectedRate) in ratesPublic {
        let rate = engine.derived.resourceRatesPerHour[resourceId, default: 0]
        #expect(abs(rate - expectedRate) < 1e-9)
    }
}

@Test @MainActor func simulationIsDeterministicForFixedSeed() {
    struct Snapshot {
        var amounts: [String: Double]
        var caps: [String: Double]
        var rates: [String: Double]
        var efficiency: Double
        var logisticsFactor: Double
        var raidChancePerHour: Double
        var collectorFoodStored: Double
        var marketCreditsIndex: Double
    }

    func makeEngine() -> GameEngine {
        let engine = GameEngine(seed: 202, shouldStartTimers: false, loadPersistence: false)
        let allAchievements = engine.content.pack.achievements.map(\.id)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        engine.debugUpdateState { state in
            state.lastSavedAt = start
            state.lastTickAt = start
            state.market.lastUpdatedAt = start
            state.collector.lastUpdatedAt = start
            state.collector.lastCollectedAt = start
            state.events = []
            state.nextEventInSeconds = 1_000_000_000
            state.achievementsUnlocked = allAchievements

            let resourceIds = Array(state.resources.keys)
            for resourceId in resourceIds {
                if var resource = state.resources[resourceId] {
                    resource.amount = 100_000
                    resource.cap = max(resource.cap, 200_000)
                    state.resources[resourceId] = resource
                }
            }

            state.buildings = [
                BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, buildingId: "farm", level: 1, x: 0, y: 0, disabledUntil: nil),
                BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!, buildingId: "irrigation_channel", level: 1, x: 1, y: 0, disabledUntil: nil),
                BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!, buildingId: "generator", level: 1, x: 10, y: 10, disabledUntil: nil),
                BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!, buildingId: "generator", level: 1, x: 11, y: 10, disabledUntil: nil),
                BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!, buildingId: "generator", level: 1, x: 10, y: 11, disabledUntil: nil),
                BuildingInstance(id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!, buildingId: "generator", level: 1, x: 11, y: 11, disabledUntil: nil)
            ]
        }

        let duration = 6 * 3600.0
        engine.simulate(seconds: duration, now: start.addingTimeInterval(duration), isOffline: true)
        return engine
    }

    func snapshot(of engine: GameEngine) -> Snapshot {
        let resourceIds = ["food", "materials", "credits", "energy", "influence"]
        var amounts: [String: Double] = [:]
        var caps: [String: Double] = [:]
        var rates: [String: Double] = [:]
        for id in resourceIds {
            amounts[id] = engine.state.resources[id]?.amount ?? 0
            caps[id] = engine.derived.resourceCaps[id, default: 0]
            rates[id] = engine.derived.resourceRatesPerHour[id, default: 0]
        }
        return Snapshot(
            amounts: amounts,
            caps: caps,
            rates: rates,
            efficiency: engine.state.stats.lastEfficiency,
            logisticsFactor: engine.state.logistics.logisticsFactor,
            raidChancePerHour: engine.state.risk.raidChancePerHour,
            collectorFoodStored: engine.state.collector.storedByResource["food", default: 0],
            marketCreditsIndex: engine.state.market.priceIndexByResource["credits", default: 0]
        )
    }

    let a = snapshot(of: makeEngine())
    let b = snapshot(of: makeEngine())

    for key in a.amounts.keys {
        #expect(abs(a.amounts[key, default: 0] - b.amounts[key, default: 0]) < 1e-9)
    }
    for key in a.caps.keys {
        #expect(abs(a.caps[key, default: 0] - b.caps[key, default: 0]) < 1e-9)
    }
    for key in a.rates.keys {
        #expect(abs(a.rates[key, default: 0] - b.rates[key, default: 0]) < 1e-9)
    }

    #expect(abs(a.efficiency - b.efficiency) < 1e-9)
    #expect(abs(a.logisticsFactor - b.logisticsFactor) < 1e-9)
    #expect(abs(a.raidChancePerHour - b.raidChancePerHour) < 1e-9)
    #expect(abs(a.collectorFoodStored - b.collectorFoodStored) < 1e-9)
    #expect(abs(a.marketCreditsIndex - b.marketCreditsIndex) < 1e-9)
}
