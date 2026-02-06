import SwiftUI

struct PeopleView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PageHeader(title: "People", subtitle: "Recruit specialists and track metahumans.") {
                    HStack(spacing: 8) {
                        Text("Roster \(engine.state.people.recruitedIds.count) / \(engine.state.people.maxRoster)")
                            .font(ClayFonts.data(11, weight: .semibold))
                            .foregroundColor(ClayTheme.accent)
                            .claySingleLine(minScale: 0.8)
                    }
                }

                if !rosterGaps().isEmpty {
                    SoftCard(title: "Roster Gaps") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(rosterGaps(), id: \.self) { gap in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(ClayTheme.accentWarm)
                                        .frame(width: 6, height: 6)
                                    Text(gap)
                                        .font(ClayFonts.data(10))
                                        .foregroundColor(ClayTheme.muted)
                                        .clayTwoLines(minScale: 0.9)
                                }
                            }
                        }
                    }
                }

                if let suggestion = suggestedRecruit() {
                    SoftCard(title: "Suggested Recruit") {
                        RecruitCard(person: suggestion)
                    }
                }

                Panel(title: "Roster") {
                    if engine.state.people.recruitedIds.isEmpty {
                        Text("No one has joined yet.")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            ForEach(engine.state.people.recruitedIds, id: \.self) { personId in
                                if let person = engine.personDefinition(for: personId) {
                                    PeopleRosterRow(person: person)
                                }
                            }
                        }
                    }
                }

                Panel(title: "Recruitment") {
                    let available = engine.availablePeople()
                    if available.isEmpty {
                        Text("No recruits available right now.")
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(sortedPeople(available)) { person in
                                RecruitCard(person: person)
                            }
                        }
                    }
                }

                Panel(title: "Metahumans") {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(engine.content.pack.metahumans) { meta in
                            MetahumanRosterCard(metahuman: meta)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func sortedPeople(_ people: [PeopleDefinition]) -> [PeopleDefinition] {
        people.sorted {
            let eraA = engine.content.erasById[$0.era]?.sortOrder ?? 0
            let eraB = engine.content.erasById[$1.era]?.sortOrder ?? 0
            if eraA == eraB { return $0.name < $1.name }
            return eraA < eraB
        }
    }

    private func rosterGaps() -> [String] {
        let recruited = engine.state.people.recruitedIds.compactMap { engine.personDefinition(for: $0) }
        let roles = recruited.map { $0.role.lowercased() }
        var gaps: [String] = []
        if !roles.contains(where: { $0.contains("logistics") }) {
            gaps.append("No logistics specialist recruited.")
        }
        if !roles.contains(where: { $0.contains("security") }) {
            gaps.append("No security specialist recruited.")
        }
        if !roles.contains(where: { $0.contains("science") }) {
            gaps.append("No science specialist recruited.")
        }
        return gaps
    }

    private func suggestedRecruit() -> PeopleDefinition? {
        let available = engine.availablePeople()
        return sortedPeople(available).first
    }
}

private struct PeopleRosterRow: View {
    let person: PeopleDefinition

    var body: some View {
        let spriteId = PixelAssetCatalog.shared.sprite(for: person.spriteId) != nil ? person.spriteId : "worker"
        HStack(spacing: 10) {
            PixelSpriteView(spriteId: spriteId, size: 22, isActive: false, bobAmplitude: 0.8, bobPeriod: 1.6)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(ClayFonts.display(12, weight: .semibold))
                    .claySingleLine(minScale: 0.75)
                Text(person.role)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.85)
            }
            Spacer(minLength: 0)
            if !person.effects.isEmpty {
                EffectSummaryList(effects: person.effects)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.8), lineWidth: 1)
        )
    }
}

private struct RecruitCard: View {
    @EnvironmentObject private var engine: GameEngine
    let person: PeopleDefinition

    var body: some View {
        let spriteId = PixelAssetCatalog.shared.sprite(for: person.spriteId) != nil ? person.spriteId : "worker"
        HStack(alignment: .top, spacing: 12) {
            PixelSpriteView(spriteId: spriteId, size: 28, isActive: false, bobAmplitude: 1.0, bobPeriod: 1.4)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.name)
                            .font(ClayFonts.display(12, weight: .semibold))
                            .claySingleLine(minScale: 0.75)
                        Text(person.role)
                            .font(ClayFonts.data(10))
                            .foregroundColor(ClayTheme.muted)
                            .claySingleLine(minScale: 0.85)
                    }
                    Spacer(minLength: 0)
                    if let rarity = person.rarity {
                        Text(rarity.uppercased())
                            .font(ClayFonts.display(9, weight: .bold))
                            .foregroundColor(ClayTheme.accent)
                            .claySingleLine(minScale: 0.7)
                    }
                }
                Text(person.description)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .clayTwoLines(minScale: 0.9)
                if !person.effects.isEmpty {
                    EffectSummaryList(effects: person.effects)
                }
                HStack(spacing: 10) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(person.costs.keys.sorted(), id: \.self) { resourceId in
                                CostPill(resourceId: resourceId, amount: person.costs[resourceId, default: 0])
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                    let block = engine.personBlockReason(person)
                    ClayButton(isEnabled: block == nil, blockedMessage: block) {
                        engine.recruitPerson(person)
                    } label: {
                        Text("Recruit")
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }
}

private struct MetahumanRosterCard: View {
    @EnvironmentObject private var engine: GameEngine
    let metahuman: MetahumanDefinition

    var body: some View {
        let disposition = engine.state.metahumans[metahuman.id]?.disposition ?? .neutral
        let effects = disposition == .ally ? metahuman.allyPassiveEffects : metahuman.enemyPassiveEffects
        HStack(alignment: .top, spacing: 12) {
            PixelSpriteView(spriteId: engine.metahumanSpriteId(metahuman), size: 32, isActive: false, bobAmplitude: 1.2, bobPeriod: 1.3)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(metahuman.name)
                        .font(ClayFonts.display(12, weight: .semibold))
                        .claySingleLine(minScale: 0.75)
                    Spacer(minLength: 0)
                    Text(disposition.label.uppercased())
                        .font(ClayFonts.display(9, weight: .bold))
                        .foregroundColor(disposition.color)
                        .claySingleLine(minScale: 0.7)
                }
                Text(metahuman.role)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .claySingleLine(minScale: 0.85)
                Text(metahuman.description)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .clayTwoLines(minScale: 0.9)
                if !effects.isEmpty {
                    EffectSummaryList(effects: effects)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(disposition.color.opacity(0.7), lineWidth: 1)
        )
    }
}

private struct EffectSummaryList: View {
    let effects: [EffectDefinition]
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(effects.enumerated()), id: \.offset) { _, effect in
                Text("• \(EffectDescriptor.describe(effect, content: engine.content))")
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.text)
            }
        }
    }
}

private struct CostPill: View {
    let resourceId: String
    let amount: Double

    var body: some View {
        HStack(spacing: 4) {
            ResourceIconView(resourceId: resourceId, size: 12, tint: ClayTheme.text)
            Text(amount.clayFormatted)
                .font(ClayFonts.data(9, weight: .semibold))
                .claySingleLine(minScale: 0.7)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.7), lineWidth: 1)
        )
    }
}

private extension MetahumanDisposition {
    var label: String {
        switch self {
        case .ally: return "Ally"
        case .enemy: return "Enemy"
        case .neutral: return "Neutral"
        }
    }

    var color: Color {
        switch self {
        case .ally: return ClayTheme.good
        case .enemy: return ClayTheme.bad
        case .neutral: return ClayTheme.muted
        }
    }
}
