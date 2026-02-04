import SwiftUI

struct HelpView: View {
    @EnvironmentObject private var engine: GameEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PageHeader(title: "Help", subtitle: "A full guide to progression, systems, and best practices.")
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    quickStart
                    coreLoop
                    resources
                    crews
                    buildings
                    projects
                    partnerships
                    raids
                    catalyst
                    events
                    domains
                    dispatches
                    metahumans
                    people
                    prestige
                    tips
                    attributions
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var quickStart: some View {
        HelpSection(title: "Quick Start") {
            HelpBullet("Build collectors first to get Food + Materials flowing.")
            HelpBullet("Avoid hitting storage caps: when a resource is full, production is wasted.")
            HelpBullet("Start Projects when you have free crews and enough resources.")
            HelpBullet("Check Intel for risks, events, and metahuman encounters.")
        }
    }

    private var coreLoop: some View {
        HelpSection(title: "Core Loop") {
            HelpBullet("Produce resources in real time, including while the app is closed.")
            HelpBullet("Spend resources on long upgrades and projects that multiply output.")
            HelpBullet("Keep storage, logistics, and defense balanced to avoid waste and raids.")
        }
    }

    private var resources: some View {
        HelpSection(title: "Resources") {
            ForEach(engine.content.pack.resources.sorted(by: { $0.sortOrder < $1.sortOrder })) { resource in
                let rate = engine.derived.resourceRatesPerHour[resource.id, default: 0]
                HelpBullet("\(resource.name): \(rate >= 0 ? "+" : "")\(rate.clayFormatted)/h. Used for builds, upgrades, and contracts.")
            }
        }
    }

    private var crews: some View {
        HelpSection(title: "Work Crews") {
            HelpBullet("Crews limit how many projects you can run at once.")
            HelpBullet("Unlock more crews by completing milestone projects.")
            HelpBullet("Keep at least one crew free for key upgrades.")
        }
    }

    private var buildings: some View {
        HelpSection(title: "Buildings") {
            HelpBullet("Collectors create resources. Storage buildings raise caps.")
            HelpBullet("Defense buildings reduce raid risk.")
            HelpBullet("Some buildings gain adjacency and district bonuses—cluster them.")
        }
    }

    private var projects: some View {
        HelpSection(title: "Projects") {
            HelpBullet("Projects are your main long-term investments.")
            HelpBullet("Use the Upgrade preview to see cost, duration, and effects.")
            HelpBullet("Project speed improves via institutions, policies, and metahuman allies.")
        }
    }

    private var partnerships: some View {
        HelpSection(title: "Partnerships") {
            HelpBullet("Contracts provide steady resource streams or multipliers.")
            HelpBullet("Maintain upkeep or relationships will drop.")
            HelpBullet("Security pacts are the easiest way to suppress raids.")
        }
    }

    private var raids: some View {
        HelpSection(title: "Raids") {
            HelpBullet("Raid risk increases when exposure is high and security is low.")
            HelpBullet("Defense buildings, pacts, and policies reduce risk.")
            HelpBullet("A well-defended base can make raids nearly vanish.")
        }
    }

    private var catalyst: some View {
        HelpSection(title: "Catalyst & Chrono Shards") {
            HelpBullet("Catalyst speeds a single project for 1 hour (cooldown applies).")
            HelpBullet("Chrono Shards skip time on a project—use them on long builds.")
        }
    }

    private var events: some View {
        HelpSection(title: "Events") {
            HelpBullet("Events bring market shocks, discoveries, and diplomacy choices.")
            HelpBullet("Decision events offer tradeoffs—read the effects carefully.")
        }
    }

    private var domains: some View {
        HelpSection(title: "Domains") {
            HelpBullet("Domains track your playstyle (Industry, Science, Diplomacy, Infrastructure).")
            HelpBullet("Completing projects grants domain points and unlocks permanent bonuses.")
        }
    }

    private var dispatches: some View {
        HelpSection(title: "Operations (Dispatches)") {
            HelpBullet("Dispatch crews on timed operations for extra rewards.")
            HelpBullet("Longer dispatches have higher risk but bigger payoffs.")
        }
    }

    private var metahumans: some View {
        HelpSection(title: "Metahumans") {
            HelpBullet("Special encounters can become allies or enemies.")
            HelpBullet("Ally deals grant powerful bonuses; bad deals can create a lasting threat.")
            HelpBullet("You can force an encounter from Intel to test the system.")
        }
    }

    private var people: some View {
        HelpSection(title: "People") {
            HelpBullet("Recruit specialists from the People tab to gain passive bonuses.")
            HelpBullet("Each recruit has a cost and may require a later era.")
            HelpBullet("Your roster size is limited—expand it with upgrades and legacy.")
        }
    }

    private var prestige: some View {
        HelpSection(title: "Prestige") {
            HelpBullet("Ascend to restart at Era 0 while keeping Legacy upgrades.")
            HelpBullet("Prestige is optional—use it when progress slows.")
        }
    }

    private var tips: some View {
        HelpSection(title: "Strategy Tips") {
            HelpBullet("Always watch time-to-cap: wasted production is lost momentum.")
            HelpBullet("Balance logistics factor near 1.0 to avoid throttled output.")
            HelpBullet("Use policies to lean into your current bottleneck.")
        }
    }

    private var attributions: some View {
        HelpSection(title: "Attribution") {
            if let packName = PixelAssetCatalog.shared.peoplePackName {
                HelpBullet("People sprites: \(packName).")
            } else {
                HelpBullet("People sprites: Default pixel pack.")
            }
            if let credits = PixelAssetCatalog.shared.peoplePackCredits {
                HelpBullet("Credits file detected in People pack.")
                Text(credits)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .lineLimit(8)
            } else {
                HelpBullet("If using LPC sprites, include the generated CREDITS file in the People pack folder.")
            }
        }
    }
}

struct HelpSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ClayFonts.display(10, weight: .semibold))
                .foregroundColor(ClayTheme.accent)
            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
}

struct HelpBullet: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(ClayTheme.accent)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(ClayFonts.data(11))
                .foregroundColor(ClayTheme.text)
        }
    }
}
