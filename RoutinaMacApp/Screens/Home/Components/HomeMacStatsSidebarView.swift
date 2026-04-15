import SwiftUI

struct HomeMacStatsSidebarView: View {
    let selectedTaskTypeFilter: StatsTaskTypeFilter
    let onSelectTaskTypeFilter: (StatsTaskTypeFilter) -> Void
    let selectedRange: DoneChartRange
    let onSelectRange: (DoneChartRange) -> Void
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let importanceUrgencySummary: String
    let allTags: [String]
    let tagSummaries: [RoutineTagSummary]
    let taskCountForSelectedTypeFilter: Int
    let selectedTag: String?
    let onSelectTag: (String?) -> Void
    let selectedExcludedTags: Set<String>
    let availableExcludeTags: [String]
    let excludedTagSummary: String
    let tagSelectionSummary: String
    let tagCount: (String) -> Int
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                statsTaskTypeSection
                statsRangeSection
                statsImportanceUrgencySection

                if !allTags.isEmpty {
                    statsTagSection
                    statsExcludedTagSection
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statsTaskTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Show")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(StatsTaskTypeFilter.allCases) { filter in
                    statsTaskTypeChip(filter)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsRangeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Range")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(DoneChartRange.allCases) { range in
                    statsRangeChip(range)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsImportanceUrgencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importance & Urgency")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            HomeMacImportanceUrgencyMatrixView(
                selectedFilter: $selectedImportanceUrgencyFilter,
                summaryText: importanceUrgencySummary
            )
            .padding(.horizontal, 4)
        }
    }

    private var statsTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filter by Tag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(tagSelectionSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                HomeMacTagChipView(
                    title: "All Tags",
                    count: taskCountForSelectedTypeFilter,
                    systemImage: "tag.slash.fill",
                    isSelected: selectedTag == nil
                ) {
                    onSelectTag(nil)
                }

                ForEach(tagSummaries) { summary in
                    HomeMacTagChipView(
                        title: "#\(summary.name)",
                        count: summary.linkedRoutineCount,
                        systemImage: "tag.fill",
                        isSelected: selectedTag == summary.name
                    ) {
                        onSelectTag(summary.name)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsExcludedTagSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exclude Tags")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(excludedTagSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            WrappingHStack(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(availableExcludeTags, id: \.self) { tag in
                    let isExcluded = selectedExcludedTags.contains { RoutineTag.contains($0, in: [tag]) }
                    HomeMacTagChipView(
                        title: "#\(tag)",
                        count: tagCount(tag),
                        systemImage: "tag.slash.fill",
                        isSelected: isExcluded,
                        selectedColor: .red
                    ) {
                        onToggleExcludedTag(tag)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statsTaskTypeChip(_ filter: StatsTaskTypeFilter) -> some View {
        Button {
            onSelectTaskTypeFilter(filter)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statsTaskTypeIcon(for: filter))
                    .font(.caption.weight(.semibold))

                Text(filter.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedTaskTypeFilter == filter ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedTaskTypeFilter == filter ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selectedTaskTypeFilter == filter ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statsTaskTypeIcon(for filter: StatsTaskTypeFilter) -> String {
        switch filter {
        case .all: return "square.grid.2x2"
        case .routines: return "repeat"
        case .todos: return "checklist"
        }
    }

    @ViewBuilder
    private func statsRangeChip(_ range: DoneChartRange) -> some View {
        Button {
            onSelectRange(range)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: statsRangeIcon(for: range))
                    .font(.caption.weight(.semibold))

                Text(range.rawValue)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selectedRange == range ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(selectedRange == range ? Color.accentColor : Color.secondary.opacity(0.10))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selectedRange == range ? Color.accentColor.opacity(0.25) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statsRangeIcon(for range: DoneChartRange) -> String {
        switch range {
        case .week: return "calendar.badge.clock"
        case .month: return "calendar"
        case .year: return "calendar.badge.plus"
        }
    }
}
