import Foundation
import ClayFeature

@main
struct BalanceSim {
    struct Config {
        var days: Int = 7
        var seed: UInt64 = 42
        var json: Bool = false
        var autoPlan: Bool = false
    }

    static func main() async {
        let config = parse()
        await MainActor.run {
            let engine = GameEngine(seed: config.seed, shouldStartTimers: false, loadPersistence: false)
            if config.autoPlan {
                engine.setAutoPlannerEnabled(true)
                ["economy", "science", "defense", "era", "accelerator", "infrastructure"].forEach {
                    engine.setAutoPlanTag($0, enabled: true)
                }
            }
            let hours = max(1, config.days * 24)
            var crewIdleSum = 0.0
            var cacheCollects = 0
            var timeToEra: [String: Int] = [:]
            for hour in 0..<hours {
                if engine.state.dispatches.isEmpty {
                    if let dispatch = engine.content.pack.dispatches.first(where: { engine.dispatchBlockReason($0) == nil }) {
                        engine.startDispatch(dispatchId: dispatch.id)
                    }
                }
                engine.simulate(seconds: 3600, isOffline: true)
                for dispatch in engine.state.dispatches where dispatch.status != .active {
                    engine.collectDispatch(id: dispatch.id)
                }
                if engine.state.collector.storedByResource.values.reduce(0, +) > 0 {
                    engine.collectCache()
                    cacheCollects += 1
                }
                let available = engine.availableCrewCount()
                crewIdleSum += Double(available) / Double(max(1, engine.state.maxCrew))
                for era in engine.content.pack.eras {
                    if timeToEra[era.id] == nil,
                       engine.state.completedProjectIds.contains(era.keystoneProjectId) {
                        timeToEra[era.id] = hour + 1
                    }
                }
            }
            let produced = engine.state.stats.totalProducedByResource
            let wasted = engine.state.stats.totalWastedByResource
            let totalProduced = produced.values.reduce(0, +)
            let totalWasted = wasted.values.reduce(0, +)
            let wastePct = totalProduced > 0 ? (totalWasted / totalProduced) * 100.0 : 0
            let crewIdlePct = (crewIdleSum / Double(hours)) * 100.0
            let raidEvents = engine.state.events.filter { $0.category == "raid" && $0.title == "Raid" }.count
            let raidRate = Double(raidEvents) / Double(config.days)
            let energyProduced = produced["energy"] ?? 0
            let domainPoints = engine.state.domainState.pointsByDomain
            let domainTiers = engine.state.domainState.unlockedTiersByDomain
            let summary: [String: Any] = [
                "days": config.days,
                "seed": config.seed,
                "energyProduced": energyProduced,
                "wastePct": wastePct,
                "crewIdlePct": crewIdlePct,
                "raidRatePerDay": raidRate,
                "timeToEraHours": timeToEra,
                "domainPoints": domainPoints,
                "domainTiers": domainTiers,
                "dispatchesCompleted": engine.state.stats.dispatchesCompleted,
                "cacheCollects": cacheCollects
            ]
            if config.json {
                if let data = try? JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys]),
                   let string = String(data: data, encoding: .utf8) {
                    print(string)
                }
            } else {
                print("BalanceSim — \(config.days) days (seed \(config.seed))")
                print("Energy Produced: \(String(format: "%.2f", energyProduced))")
                print("Overflow Waste: \(String(format: "%.2f", wastePct))%")
                print("Crew Idle: \(String(format: "%.2f", crewIdlePct))%")
                print("Raid Rate: \(String(format: "%.2f", raidRate)) per day")
                for era in engine.content.pack.eras.sorted(by: { $0.sortOrder < $1.sortOrder }) {
                    if let hour = timeToEra[era.id] {
                        let days = Double(hour) / 24.0
                        print("Era \(era.name): \(String(format: "%.2f", days)) days")
                    }
                }
            }
        }
    }

    static func parse() -> Config {
        var config = Config()
        var iterator = CommandLine.arguments.dropFirst().makeIterator()
        while let arg = iterator.next() {
            switch arg {
            case "--days":
                if let value = iterator.next(), let parsed = Int(value) {
                    config.days = parsed
                }
            case "--seed":
                if let value = iterator.next(), let parsed = UInt64(value) {
                    config.seed = parsed
                }
            case "--json":
                config.json = true
            case "--autoplan":
                config.autoPlan = true
            default:
                break
            }
        }
        return config
    }
}
