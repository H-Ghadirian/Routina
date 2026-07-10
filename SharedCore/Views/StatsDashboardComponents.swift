import SwiftUI

struct StatsHeroStatPill: View {
    let icon: String
    let title: String
    let value: String
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .routinaGlassCard(cornerRadius: 12, tint: .white, tintOpacity: colorScheme == .dark ? 0.12 : 0.24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .routinaGlassCard(cornerRadius: 18, tint: .white, tintOpacity: colorScheme == .dark ? 0.08 : 0.2)
    }
}

enum StatsSummaryDisplayMode: String, CaseIterable, Identifiable {
    case cards
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cards:
            return "Cards"
        case .compact:
            return "Compact"
        }
    }

    var systemImage: String {
        switch self {
        case .cards:
            return "square.grid.2x2"
        case .compact:
            return "rectangle.grid.1x2"
        }
    }
}

enum StatsDashboardScope: String, CaseIterable, Identifiable {
    case all
    case focus
    case sleep
    case wins
    case achievements

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .focus:
            return "Focus"
        case .sleep:
            return "Sleep"
        case .wins:
            return "Wins"
        case .achievements:
            return "Achievements"
        }
    }
}

struct StatsSummaryCard<Accessory: View>: View {
    let icon: String
    let accent: Color
    let title: String
    let value: String
    let caption: String?
    let accessibilityIdentifier: String
    let colorScheme: ColorScheme
    let surfaceGradient: LinearGradient
    let accessibilityChildren: AccessibilityChildBehavior
    let accessory: () -> Accessory

    init(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String? = nil,
        accessibilityIdentifier: String,
        colorScheme: ColorScheme,
        surfaceGradient: LinearGradient,
        accessibilityChildren: AccessibilityChildBehavior = .combine,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.icon = icon
        self.accent = accent
        self.title = title
        self.value = value
        self.caption = caption
        self.accessibilityIdentifier = accessibilityIdentifier
        self.colorScheme = colorScheme
        self.surfaceGradient = surfaceGradient
        self.accessibilityChildren = accessibilityChildren
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .routinaGlassCard(cornerRadius: 14, tint: accent, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)

                Spacer(minLength: 0)
                accessory()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                if let caption {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
        .padding(18)
        .routinaGlassPanel(cornerRadius: 24, tint: accent, tintOpacity: colorScheme == .dark ? 0.12 : 0.08)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: accessibilityChildren)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityValue: String {
        guard let caption else { return value }
        return "\(value). \(caption)"
    }
}

struct StatsCompactSummaryCard<Accessory: View>: View {
    let icon: String
    let accent: Color
    let title: String
    let value: String
    let caption: String?
    let accessibilityIdentifier: String
    let colorScheme: ColorScheme
    let surfaceGradient: LinearGradient
    let accessibilityChildren: AccessibilityChildBehavior
    let accessory: () -> Accessory

    init(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String? = nil,
        accessibilityIdentifier: String,
        colorScheme: ColorScheme,
        surfaceGradient: LinearGradient,
        accessibilityChildren: AccessibilityChildBehavior = .combine,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.icon = icon
        self.accent = accent
        self.title = title
        self.value = value
        self.caption = caption
        self.accessibilityIdentifier = accessibilityIdentifier
        self.colorScheme = colorScheme
        self.surfaceGradient = surfaceGradient
        self.accessibilityChildren = accessibilityChildren
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .routinaGlassCard(cornerRadius: 12, tint: accent, tintOpacity: colorScheme == .dark ? 0.18 : 0.12)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font((caption == nil ? Font.subheadline : Font.caption).weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 8) {
                accessory()

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .routinaGlassPanel(cornerRadius: 18, tint: accent, tintOpacity: colorScheme == .dark ? 0.1 : 0.07)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4), lineWidth: 1)
        )
        .accessibilityElement(children: accessibilityChildren)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityValue: String {
        guard let caption else { return value }
        return "\(value). \(caption)"
    }
}

struct StatsSectionHeader<Accessory: View>: View {
    let title: String
    let subtitle: String
    let accessory: () -> Accessory

    init(
        title: String,
        subtitle: String,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            accessory()
        }
    }
}

extension StatsSummaryCard where Accessory == EmptyView {
    init(
        icon: String,
        accent: Color,
        title: String,
        value: String,
        caption: String? = nil,
        accessibilityIdentifier: String,
        colorScheme: ColorScheme,
        surfaceGradient: LinearGradient
    ) {
        self.init(
            icon: icon,
            accent: accent,
            title: title,
            value: value,
            caption: caption,
            accessibilityIdentifier: accessibilityIdentifier,
            colorScheme: colorScheme,
            surfaceGradient: surfaceGradient,
            accessory: { EmptyView() }
        )
    }
}

struct StatsSmallHighlightBadge: View {
    let title: String
    let value: String
    let colorScheme: ColorScheme
    let surfaceGradient: LinearGradient

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .routinaGlassCard(cornerRadius: 18, tint: .accentColor, tintOpacity: 0.10)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.35), lineWidth: 1)
        )
    }
}

struct StatsBottomInsightPill: View {
    let icon: String
    let text: String
    let colorScheme: ColorScheme

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .routinaGlassPill(tint: .secondary, tintOpacity: colorScheme == .dark ? 0.14 : 0.06)
    }
}

struct StatsChartInsight {
    let systemImage: String
    let text: String
}

struct StatsChartInsightRow: View {
    let insights: [StatsChartInsight]
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                StatsBottomInsightPill(
                    icon: insight.systemImage,
                    text: insight.text,
                    colorScheme: colorScheme
                )
            }
        }
    }
}

struct StatsHorizontalChartContainer<Content: View>: View {
    let chartPresentation: StatsChartPresentation
    let minHeight: CGFloat
    private let content: () -> Content

    init(
        chartPresentation: StatsChartPresentation,
        minHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.chartPresentation = chartPresentation
        self.minHeight = minHeight
        self.content = content
    }

    var body: some View {
        Group {
            if chartPresentation.usesHorizontalChartScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    content()
                        .frame(minWidth: chartPresentation.chartMinWidth, minHeight: minHeight)
                        .padding(.top, 4)
                }
                .defaultScrollAnchor(.trailing)
            } else {
                content()
                    .frame(maxWidth: .infinity, minHeight: minHeight)
                    .padding(.top, 4)
            }
        }
    }
}

enum StatsChartFill {
    static func focusBar(colorScheme: ColorScheme) -> LinearGradient {
        LinearGradient(
            colors: [
                Color.teal.opacity(colorScheme == .dark ? 0.78 : 0.64),
                Color.mint.opacity(colorScheme == .dark ? 0.6 : 0.5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum StatsChartCountAxis {
    static func upperBound(for rawUpperBound: Double) -> Double {
        max(1, ceil(rawUpperBound))
    }

    static func values(upperBound: Double) -> [Double] {
        let upperBound = max(1, ceil(upperBound))
        if upperBound <= 2 {
            return [0, upperBound]
        }

        return [0, floor(upperBound / 2), upperBound]
    }

    static func label(for count: Double) -> String {
        Int(count.rounded()).formatted()
    }
}

enum StatsChartTimeAxis {
    static func upperBound(for rawUpperBound: Double) -> Double {
        let rawUpperBound = max(rawUpperBound, 10)
        let step: Double

        switch rawUpperBound {
        case ...30:
            step = 10
        case ...120:
            step = 30
        case ...360:
            step = 60
        case ...720:
            step = 120
        default:
            step = 240
        }

        return ceil(rawUpperBound / step) * step
    }

    static func values(upperBound: Double) -> [Double] {
        [0, upperBound / 2, upperBound]
    }

    static func label(for minutes: Double) -> String {
        guard minutes > 0 else { return "0m" }
        return FocusSessionFormatting.compactDurationText(seconds: TimeInterval(minutes.rounded() * 60))
    }
}

struct StatsEmptyChartStateView: View {
    let systemImage: String
    let message: String
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .statsChartPlotBackground(colorScheme: colorScheme)
    }
}

struct StatsEmptyDashboardStateView: View {
    let hasActiveFilters: Bool
    let colorScheme: ColorScheme

    private var message: String {
        if hasActiveFilters {
            return "No reports match this time range and filters yet. Try a wider range or clear filters to see more activity."
        }

        return "Reports appear after you complete tasks, focus, sleep, or log activity in this period."
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text("No stats to show yet")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
        .padding(24)
        .routinaGlassPanel(cornerRadius: 28, tint: .accentColor, tintOpacity: 0.06)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func statsChartCard(
        surfaceGradient: LinearGradient,
        colorScheme: ColorScheme
    ) -> some View {
        padding(20)
            .routinaGlassPanel(cornerRadius: 28, tint: .accentColor, tintOpacity: 0.07)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), lineWidth: 1)
            )
    }

    func statsChartPlotBackground(colorScheme: ColorScheme) -> some View {
        routinaGlassCard(cornerRadius: 18, tint: .secondary, tintOpacity: colorScheme == .dark ? 0.12 : 0.05)
    }
}
