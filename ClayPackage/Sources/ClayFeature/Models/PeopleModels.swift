import Foundation

public struct PeopleDefinition: Codable, Identifiable {
    public var id: String
    public var name: String
    public var description: String
    public var era: String
    public var role: String
    public var spriteId: String
    public var costs: ResourceAmount
    public var effects: [EffectDefinition]
    public var rarity: String?

    public init(
        id: String,
        name: String,
        description: String,
        era: String,
        role: String,
        spriteId: String,
        costs: ResourceAmount,
        effects: [EffectDefinition],
        rarity: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.era = era
        self.role = role
        self.spriteId = spriteId
        self.costs = costs
        self.effects = effects
        self.rarity = rarity
    }
}

public struct PeopleState: Codable {
    public var recruitedIds: [String]
    public var maxRoster: Int

    public init(recruitedIds: [String], maxRoster: Int) {
        self.recruitedIds = recruitedIds
        self.maxRoster = maxRoster
    }
}
