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

struct StatsDashboardToolbarAvailability: Equatable {
    let showsSummaryDisplayMode: Bool
    let showsEditor: Bool
    let showsFilters: Bool

    var showsAnyControl: Bool {
        showsSummaryDisplayMode || showsEditor || showsFilters
    }

    static func make(
        hasReportableDashboardItems: Bool,
        hasVisibleSummaryItems: Bool,
        hasFilterableTasks: Bool,
        hasActiveSheetFilters: Bool
    ) -> Self {
        Self(
            showsSummaryDisplayMode: hasVisibleSummaryItems,
            showsEditor: hasReportableDashboardItems,
            showsFilters: hasFilterableTasks || hasActiveSheetFilters
        )
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
    let isCompactTile: Bool
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
        isCompactTile: Bool = false,
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
        self.isCompactTile = isCompactTile
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompactTile ? 10 : 18) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(isCompactTile ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(
                        width: isCompactTile ? 34 : 42,
                        height: isCompactTile ? 34 : 42
                    )
                    .routinaGlassCard(
                        cornerRadius: isCompactTile ? 12 : 14,
                        tint: accent,
                        tintOpacity: colorScheme == .dark ? 0.18 : 0.12
                    )

                if isCompactTile {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 0)
                accessory()
            }

            if isCompactTile {
                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)

                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            } else {
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
        }
        .frame(
            maxWidth: .infinity,
            minHeight: isCompactTile ? 112 : 160,
            alignment: .topLeading
        )
        .padding(isCompactTile ? 14 : 18)
        .routinaGlassPanel(
            cornerRadius: isCompactTile ? 20 : 24,
            tint: accent,
            tintOpacity: colorScheme == .dark ? 0.12 : 0.08
        )
        .overlay(
            RoundedRectangle(cornerRadius: isCompactTile ? 20 : 24, style: .continuous)
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
                    .fixedSize(horizontal: false, vertical: true)

                if let caption {
                    Text(caption)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

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
