import Foundation

public struct ContentCatalog {
    public let pack: ContentPack
    public let resourcesById: [String: ResourceDefinition]
    public let buildingsById: [String: BuildingDefinition]
    public let projectsById: [String: ProjectDefinition]
    public let erasById: [String: EraDefinition]
    public let factionsById: [String: FactionDefinition]
    public let contractsById: [String: ContractDefinition]
    public let policiesById: [String: PolicyDefinition]
    public let eventChainsById: [String: EventChainDefinition]
    public let ambientEntitiesById: [String: AmbientEntityDefinition]
    public let legacyUpgradesById: [String: LegacyUpgradeDefinition]
    public let metahumansById: [String: MetahumanDefinition]
    public let peopleById: [String: PeopleDefinition]
    public let domainsById: [String: DomainDefinition]
    public let dispatchesById: [String: DispatchDefinition]
    public let megaprojectFamiliesById: [String: MegaprojectFamilyDefinition]
    public let achievementsById: [String: AchievementDefinition]
    
    public init(pack: ContentPack) {
        self.pack = pack
        self.resourcesById = Dictionary(uniqueKeysWithValues: pack.resources.map { ($0.id, $0) })
        self.buildingsById = Dictionary(uniqueKeysWithValues: pack.buildings.map { ($0.id, $0) })
        self.projectsById = Dictionary(uniqueKeysWithValues: pack.projects.map { ($0.id, $0) })
        self.erasById = Dictionary(uniqueKeysWithValues: pack.eras.map { ($0.id, $0) })
        self.factionsById = Dictionary(uniqueKeysWithValues: pack.factions.map { ($0.id, $0) })
        self.contractsById = Dictionary(uniqueKeysWithValues: pack.contracts.map { ($0.id, $0) })
        self.policiesById = Dictionary(uniqueKeysWithValues: pack.policies.map { ($0.id, $0) })
        self.eventChainsById = Dictionary(uniqueKeysWithValues: pack.eventChains.map { ($0.id, $0) })
        self.ambientEntitiesById = Dictionary(uniqueKeysWithValues: pack.ambientEntities.map { ($0.id, $0) })
        self.legacyUpgradesById = Dictionary(uniqueKeysWithValues: pack.legacyUpgrades.map { ($0.id, $0) })
        self.metahumansById = Dictionary(uniqueKeysWithValues: pack.metahumans.map { ($0.id, $0) })
        self.peopleById = Dictionary(uniqueKeysWithValues: pack.people.map { ($0.id, $0) })
        self.domainsById = Dictionary(uniqueKeysWithValues: pack.domains.map { ($0.id, $0) })
        self.dispatchesById = Dictionary(uniqueKeysWithValues: pack.dispatches.map { ($0.id, $0) })
        self.megaprojectFamiliesById = Dictionary(uniqueKeysWithValues: pack.megaprojectFamilies.map { ($0.id, $0) })
        self.achievementsById = Dictionary(uniqueKeysWithValues: pack.achievements.map { ($0.id, $0) })
    }
}

public enum ContentLoader {
    @MainActor
    public static func load() -> ContentCatalog {
        guard let url = Bundle.module.url(forResource: "content", withExtension: "json") else {
            fatalError("Missing content.json in bundle resources")
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let pack = try decoder.decode(ContentPack.self, from: data)
            let catalog = ContentCatalog(pack: pack)
#if DEBUG
            validate(catalog: catalog)
#endif
            return catalog
        } catch {
            fatalError("Failed to load content.json: \(error)")
        }
    }

    @MainActor
    private static func validate(catalog: ContentCatalog) {
        var errors: [String] = []
        func validateEffects(_ effects: [EffectDefinition], context: String) {
            for effect in effects {
                if let buildingId = effect.buildingId, catalog.buildingsById[buildingId] == nil {
                    errors.append("\(context) references missing building \(buildingId).")
                }
                if let projectId = effect.projectId, catalog.projectsById[projectId] == nil {
                    errors.append("\(context) references missing project \(projectId).")
                }
                if let eraId = effect.eraId, catalog.erasById[eraId] == nil {
                    errors.append("\(context) references missing era \(eraId).")
                }
                if let contractId = effect.contractId, catalog.contractsById[contractId] == nil {
                    errors.append("\(context) references missing contract \(contractId).")
                }
                if let factionId = effect.factionId, catalog.factionsById[factionId] == nil {
                    errors.append("\(context) references missing faction \(factionId).")
                }
                if let metahumanId = effect.metahumanId, catalog.metahumansById[metahumanId] == nil {
                    errors.append("\(context) references missing metahuman \(metahumanId).")
                }
            }
        }
        for era in catalog.pack.eras {
            let keystoneIds = era.keystoneProjectIds ?? [era.keystoneProjectId]
            for keystoneId in keystoneIds {
                if catalog.projectsById[keystoneId] == nil {
                    errors.append("Era \(era.id) references missing keystone project \(keystoneId).")
                }
            }
        }
        for project in catalog.pack.projects {
            validateEffects(project.effects, context: "Project \(project.id)")
        }
        for person in catalog.pack.people {
            validateEffects(person.effects, context: "Person \(person.id)")
        }
        for chain in catalog.pack.eventChains {
            for nextId in chain.nextIds {
                if catalog.eventChainsById[nextId] == nil {
                    errors.append("Event chain \(chain.id) references missing next chain \(nextId).")
                }
            }
            for choice in chain.choices {
                if let nextId = choice.nextId, catalog.eventChainsById[nextId] == nil {
                    errors.append("Event chain \(chain.id) choice \(choice.id) references missing next chain \(nextId).")
                }
            }
        }
        for domain in catalog.pack.domains {
            for tier in domain.tiers {
                validateEffects(tier.effects, context: "Domain \(domain.id) tier \(tier.tier)")
            }
        }
        for achievement in catalog.pack.achievements {
            validateEffects(achievement.effects, context: "Achievement \(achievement.id)")
            if let domainId = achievement.condition.domainId, catalog.domainsById[domainId] == nil {
                errors.append("Achievement \(achievement.id) references missing domain \(domainId).")
            }
        }
        for dispatch in catalog.pack.dispatches {
            if catalog.erasById[dispatch.era] == nil {
                errors.append("Dispatch \(dispatch.id) references missing era \(dispatch.era).")
            }
        }
        if catalog.pack.collector.capacityHours <= 0 {
            errors.append("Collector capacityHours must be positive.")
        }
        for family in catalog.pack.megaprojectFamilies {
            for choice in family.choices {
                if catalog.projectsById[choice] == nil {
                    errors.append("Megaproject family \(family.familyId) references missing project \(choice).")
                }
            }
        }
        let kenney = KenneyAssetCatalog.shared
        for building in catalog.pack.buildings {
            if kenney.buildingAsset(for: building.id) == nil {
                errors.append("Missing Kenney asset mapping for building \(building.id).")
            }
        }
        for resource in catalog.pack.resources {
            if kenney.resourceIconPath(for: resource.id) == nil {
                errors.append("Missing Kenney resource icon for \(resource.id).")
            }
        }
        for entity in catalog.pack.ambientEntities {
            if kenney.url(for: entity.model3d) == nil {
                errors.append("Missing Kenney model for ambient entity \(entity.id).")
            }
        }
        if !errors.isEmpty {
            fatalError("Content validation failed:\n" + errors.joined(separator: "\n"))
        }
    }
}
