import SwiftUI

enum GuidancePriority: Int, Comparable, CaseIterable {
    case urgent = 3
    case high = 2
    case medium = 1
    case low = 0

    static func < (lhs: GuidancePriority, rhs: GuidancePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var tint: Color {
        switch self {
        case .urgent: return ClayTheme.bad
        case .high: return ClayTheme.accentWarm
        case .medium: return ClayTheme.accent
        case .low: return ClayTheme.muted
        }
    }

    var label: String {
        switch self {
        case .urgent: return "Urgent"
        case .high: return "High"
        case .medium: return "Next"
        case .low: return "Info"
        }
    }
}

enum GuidanceAction: Equatable {
    case none
    case switchTab(ClayTab)
    case collectCache
    case collectDispatches
    case reviewIntel
    case openResource(String)
}

struct GuidanceItem: Identifiable, Equatable {
    /// Stable identity is critical: these items are recomputed frequently, and unstable IDs can
    /// cause SwiftUI to churn the view tree and (on macOS) trigger pathological constraint passes.
    let id: String
    let title: String
    let detail: String
    let priority: GuidancePriority
    let action: GuidanceAction
}

struct GuidanceSummary {
    let total: Int
    let urgent: Int
    let high: Int
}

struct GuidanceCenterView: View {
    @EnvironmentObject private var engine: GameEngine
    let maxItems: Int
    var showEmpty: Bool = true

    var body: some View {
        let items = Array(engine.guidanceItems().prefix(maxItems))
        if items.isEmpty {
            if showEmpty {
                EmptyState(title: "All Clear", subtitle: "No immediate actions required.")
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items) { item in
                    GuidanceItemRow(item: item) {
                        perform(action: item.action)
                    }
                }
            }
        }
    }

    private func perform(action: GuidanceAction) {
        switch action {
        case .none:
            break
        case .switchTab(let tab):
            NotificationCenter.default.post(name: .claySwitchTab, object: tab)
        case .collectCache:
            engine.collectCache()
        case .collectDispatches:
            let collectable = engine.state.dispatches.filter { $0.status != .active }
            for dispatch in collectable {
                engine.collectDispatch(id: dispatch.id)
            }
        case .reviewIntel:
            NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.intel)
        case .openResource(let resourceId):
            NotificationCenter.default.post(name: .clayToast, object: ToastPayload(message: "Review \(resourceId.capitalized) details", style: .info))
            NotificationCenter.default.post(name: .claySwitchTab, object: ClayTab.base)
        }
    }
}

private struct GuidanceItemRow: View {
    let item: GuidanceItem
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(ClayFonts.display(10, weight: .semibold))
                        .foregroundColor(ClayTheme.text)
                        .claySingleLine(minScale: 0.8)
                    InlineStatusPill(text: item.priority.label, tint: item.priority.tint)
                }
                Text(item.detail)
                    .font(ClayFonts.data(9))
                    .foregroundColor(ClayTheme.muted)
                    .clayTwoLines(minScale: 0.9)
            }
            Spacer(minLength: 0)
            if let cta = actionTitle(for: item.action) {
                ClayButton(isEnabled: true, active: true) {
                    action()
                } label: {
                    Text(cta)
                        .claySingleLine(minScale: 0.75)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(item.priority.tint.opacity(0.35), lineWidth: 1)
        )
    }

    private func actionTitle(for action: GuidanceAction) -> String? {
        switch action {
        case .none:
            return nil
        case .switchTab(let tab):
            switch tab {
            case .base: return "Base"
            case .projects: return "Projects"
            case .operations: return "Ops"
            case .partnerships: return "Deals"
            case .intel: return "Intel"
            case .people: return "People"
            case .domains: return "Domains"
            case .achievements: return "Awards"
            case .progress: return "Progress"
            case .help: return "Help"
            case .settings: return "Settings"
            }
        case .collectCache:
            return "Collect"
        case .collectDispatches:
            return "Collect"
        case .reviewIntel:
            return "Review"
        case .openResource:
            return "Inspect"
        }
    }
}
