import SwiftUI

struct HomeMacStatsQuerySection: View {
    @Binding var advancedQuery: String
    let queryOptions: HomeAdvancedQueryOptions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacStatsSectionTitle("Query")

            HomeAdvancedQueryBuilder(
                query: $advancedQuery,
                usesFlowLayout: true,
                options: queryOptions
            )
        }
    }
}

struct HomeMacStatsTaskTypeSection: View {
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacStatsSectionTitle("Show")

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(StatsTaskTypeFilter.allCases) { filter in
                    HomeMacStatsOptionChip(
                        title: filter.rawValue,
                        systemImage: filter.macSidebarIconName,
                        isSelected: selectedTaskTypeFilter == filter
                    ) {
                        onSelectTaskTypeFilter(filter)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HomeMacStatsRangeSection: View {
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacStatsSectionTitle("Time Range")

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(DoneChartRange.allCases) { range in
                    HomeMacStatsOptionChip(
                        title: range.rawValue,
                        systemImage: range.macSidebarIconName,
                        isSelected: selectedRange == range
                    ) {
                        onSelectRange(range)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct HomeMacStatsImportanceUrgencySection: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeMacStatsSectionTitle("Importance & Urgency")

            HomeMacImportanceUrgencyMatrixView(
                selectedFilter: $selectedFilter,
                summaryText: summaryText
            )
            .padding(.horizontal, 4)
        }
    }
}

struct HomeMacStatsSectionTitle: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }
}

private struct HomeMacStatsOptionChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private extension StatsTaskTypeFilter {
    var macSidebarIconName: String {
        switch self {
        case .all:
            return "square.grid.2x2"
        case .routines:
            return "repeat"
        case .todos:
            return "checklist"
        }
    }
}

private extension DoneChartRange {
    var macSidebarIconName: String {
        switch self {
        case .today:
            return "calendar.badge.checkmark"
        case .week:
            return "calendar.badge.clock"
        case .month:
            return "calendar"
        case .year:
            return "calendar.badge.plus"
        }
    }
}
