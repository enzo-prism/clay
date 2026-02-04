import SwiftUI

struct PageHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    let actions: Actions

    init(title: String, subtitle: String? = nil, @ViewBuilder actions: () -> Actions = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(ClayFonts.display(14, weight: .bold))
                    .foregroundColor(ClayTheme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(ClayFonts.data(10))
                        .foregroundColor(ClayTheme.muted)
                }
            }
            Spacer()
            actions
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}

enum HintTone {
    case info
    case warning
    case danger

    var color: Color {
        switch self {
        case .info: return ClayTheme.accent
        case .warning: return ClayTheme.accentWarm
        case .danger: return ClayTheme.bad
        }
    }

    var icon: String {
        switch self {
        case .info: return "KenneySelected/Icons/icon_info.png"
        case .warning: return "KenneySelected/Icons/icon_power.png"
        case .danger: return "KenneySelected/Icons/icon_target.png"
        }
    }
}

struct HintBanner: View {
    let message: String
    var tone: HintTone = .info

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            KenneyIconView(path: tone.icon, size: 14, tint: tone.color)
                .padding(.top, 2)
            Text(message)
                .font(ClayFonts.data(10))
                .foregroundColor(ClayTheme.text)
            Spacer(minLength: 0)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(tone.color.opacity(0.6), lineWidth: 1)
        )
    }
}

struct Panel<Content: View>: View {
    let title: String?
    let content: Content
    
    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                SectionHeader(title: title)
            }
            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .fill(ClayTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radius, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.8), lineWidth: ClayMetrics.borderWidth)
        )
        .shadow(color: ClayTheme.shadow, radius: 10, x: 0, y: 6)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(ClayTheme.stroke)
                .frame(height: 1)
                .offset(y: 8)
            HStack(spacing: 8) {
                Rectangle()
                    .fill(ClayTheme.accentGradient)
                    .frame(width: 6, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                Text(title.uppercased())
                    .font(ClayFonts.display(10, weight: .semibold))
                    .foregroundColor(ClayTheme.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
    }
}

struct HUDChip: View {
    let title: String
    let value: String
    let subvalue: String
    let color: Color
    let iconPath: String?
    let resourceId: String?
    var activity: HUDChipActivity = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var sheenPhase: CGFloat = -1
    
    var body: some View {
        let borderColor = activityBorderColor()
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(color)
            HStack(spacing: 6) {
                if let resourceId {
                    ResourceIconView(resourceId: resourceId, size: 12, tint: color)
                } else {
                    KenneyIconView(path: iconPath, size: 12, tint: color)
                }
                Text(value)
                    .font(ClayFonts.data(12, weight: .medium))
                    .foregroundColor(ClayTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Text(subvalue)
                    .font(ClayFonts.data(10))
                    .foregroundColor(ClayTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .overlay(
            Group {
                if activity == .positive && !reduceMotion {
                    SheenOverlay(phase: sheenPhase)
                        .clipShape(RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous))
                }
            }
        )
        .onAppear {
            startActivityAnimation()
        }
        .onChange(of: activity) { _ in
            startActivityAnimation()
        }
        .onChange(of: reduceMotion) { _ in
            startActivityAnimation()
        }
    }

    private func activityBorderColor() -> Color {
        switch activity {
        case .warning:
            return ClayTheme.accentWarm.opacity(pulse ? 0.9 : 0.4)
        case .negative:
            return ClayTheme.bad.opacity(pulse ? 0.9 : 0.4)
        default:
            return ClayTheme.stroke.opacity(0.6)
        }
    }

    private func startActivityAnimation() {
        guard !reduceMotion else {
            pulse = false
            sheenPhase = -1
            return
        }
        if activity == .warning || activity == .negative {
            pulse = false
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
        }
        if activity == .positive {
            sheenPhase = -1
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                sheenPhase = 1
            }
        } else {
            sheenPhase = -1
        }
    }
}

enum HUDChipActivity {
    case idle
    case positive
    case negative
    case warning
}

private struct SheenOverlay: View {
    let phase: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let band = max(18, proxy.size.width * 0.35)
            let offset = (proxy.size.width + band) * phase - band
            LinearGradient(
                colors: [Color.white.opacity(0.0), Color.white.opacity(0.12), Color.white.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: band, height: proxy.size.height)
            .offset(x: offset)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let accent: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(ClayFonts.display(9, weight: .semibold))
                .foregroundColor(ClayTheme.muted)
            Text(value)
                .font(ClayFonts.data(13, weight: .semibold))
                .foregroundColor(accent)
            SimpleProgressBar(value: progressValue)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(ClayTheme.panelElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
        )
    }
    
    private var progressValue: Double {
        if let value = Double(value) {
            return min(1.0, max(0, value))
        }
        return 0
    }
}

struct ClayButtonStyle: ButtonStyle {
    let active: Bool
    var hovering: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        let base = active ? ClayTheme.accent : ClayTheme.panelElevated
        let hoverFill = active ? ClayTheme.accent.opacity(0.9) : ClayTheme.panelElevated.opacity(0.9)
        let pressedFill = active ? ClayTheme.accent.opacity(0.8) : ClayTheme.panelElevated.opacity(0.85)
        let fill = configuration.isPressed ? pressedFill : (hovering ? hoverFill : base)
        let textColor = active ? ClayTheme.accentText : ClayTheme.muted
        return configuration.label
            .font(ClayFonts.display(10, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .background(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                    .stroke(hovering ? ClayTheme.accent.opacity(0.8) : ClayTheme.stroke.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous))
            .contentShape(Rectangle())
            .opacity(active ? 1.0 : 0.8)
    }
}

struct ClayButton<Label: View>: View {
    @EnvironmentObject private var toastCenter: ToastCenter
    let isEnabled: Bool
    let active: Bool
    let blockedMessage: String?
    let action: () -> Void
    let label: () -> Label
    @State private var hovering = false
    
    init(isEnabled: Bool = true, active: Bool? = nil, blockedMessage: String? = nil, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.isEnabled = isEnabled
        self.active = active ?? isEnabled
        self.blockedMessage = blockedMessage
        self.action = action
        self.label = label
    }
    
    var body: some View {
        Button {
            if isEnabled {
                action()
            } else if let message = blockedMessage {
                toastCenter.push(message: message, style: .warning)
            }
        } label: {
            label()
        }
        .buttonStyle(ClayButtonStyle(active: active, hovering: hovering))
        .onHover { hovering = $0 }
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

struct SimpleProgressBar: View {
    let value: Double
    var height: CGFloat = 8
    var isActive: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerPhase: CGFloat = -1
    
    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0.0, min(1.0, value))
            let fillWidth = max(4, proxy.size.width * CGFloat(clamped))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(ClayTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                            .stroke(ClayTheme.stroke.opacity(0.6), lineWidth: 1)
                    )
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(ClayTheme.accent)
                    .frame(width: fillWidth)
                    .overlay(
                        Group {
                            if isActive && !reduceMotion {
                                ProgressSheen(phase: shimmerPhase, width: fillWidth, height: height)
                                    .opacity(0.7)
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: height / 2, style: .continuous))
            }
        }
        .frame(height: height)
        .onAppear {
            startShimmerIfNeeded()
        }
        .onChange(of: isActive) { _ in
            startShimmerIfNeeded()
        }
        .onChange(of: reduceMotion) { _ in
            startShimmerIfNeeded()
        }
    }
    
    private func startShimmerIfNeeded() {
        guard isActive && !reduceMotion else {
            shimmerPhase = -1
            return
        }
        shimmerPhase = -1
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }
}

private struct ProgressSheen: View {
    let phase: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var body: some View {
        let band = max(12, width * 0.35)
        let offset = (width + band) * phase - band
        return LinearGradient(
            colors: [Color.white.opacity(0.0), Color.white.opacity(0.35), Color.white.opacity(0.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: band, height: height)
        .offset(x: offset)
    }
}

struct SimpleToggle: View {
    let label: String
    @Binding var isOn: Bool
    var identifier: String? = nil
    @State private var hovering = false
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Text(label)
                    .font(ClayFonts.display(11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .layoutPriority(1)
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isOn ? ClayTheme.accent : ClayTheme.panelElevated)
                        .frame(width: 46, height: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(ClayTheme.stroke.opacity(0.9), lineWidth: 1)
                        )
                    Circle()
                        .fill(ClayTheme.text)
                        .frame(width: 16, height: 16)
                        .padding(3)
                        .overlay(
                            Circle()
                                .stroke(ClayTheme.stroke.opacity(0.95), lineWidth: 1)
                        )
                        .shadow(color: ClayTheme.shadow.opacity(0.5), radius: 2, x: 0, y: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: ClayMetrics.radiusSmall, style: .continuous)
                .fill(hovering ? ClayTheme.panelElevated.opacity(0.9) : Color.clear)
        )
        .accessibilityIdentifier(identifier ?? label)
        .onHover { hovering = $0 }
    }
}
