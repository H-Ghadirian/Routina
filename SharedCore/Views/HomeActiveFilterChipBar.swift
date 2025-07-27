import SwiftUI

struct HomeActiveFilterChipBar: View {
    let taskListViewMode: HomeTaskListViewMode
    let taskListSortOrder: HomeTaskListSortOrder
    let createdDateFilter: HomeTaskCreatedDateFilter
    let advancedQuery: String
    let selectedTags: Set<String>
    let excludedTags: Set<String>
    let selectedPlaceName: String?
    let selectedImportanceUrgencyFilterLabel: String?
    let selectedPressureFilter: RoutineTaskPressure?
    let hideUnavailableRoutines: Bool
    let onClearAll: () -> Void
    let onClearTaskListViewMode: () -> Void
    let onClearTaskListSortOrder: () -> Void
    let onClearCreatedDateFilter: () -> Void
    let onClearAdvancedQuery: () -> Void
    let onRemoveIncludedTag: (String) -> Void
    let onRemoveExcludedTag: (String) -> Void
    let onClearPlace: () -> Void
    let onClearImportanceUrgency: () -> Void
    let onClearPressure: () -> Void
    let onShowUnavailableRoutines: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("Clear All", action: onClearAll)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                if taskListViewMode != .all {
                    HomeActiveFilterChip(
                        title: "View: \(taskListViewMode.title)",
                        systemImage: taskListViewMode.systemImage,
                        action: onClearTaskListViewMode
                    )
                }

                if taskListSortOrder != .smart {
                    HomeActiveFilterChip(
                        title: "Created: \(taskListSortOrder.title)",
                        systemImage: taskListSortOrder.systemImage,
                        action: onClearTaskListSortOrder
                    )
                }

                if createdDateFilter != .all {
                    HomeActiveFilterChip(
                        title: createdDateFilter.title,
                        systemImage: createdDateFilter.systemImage,
                        action: onClearCreatedDateFilter
                    )
                }

                let trimmedAdvancedQuery = advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedAdvancedQuery.isEmpty {
                    HomeActiveFilterChip(
                        title: "Query: \(trimmedAdvancedQuery)",
                        systemImage: "text.magnifyingglass",
                        action: onClearAdvancedQuery
                    )
                }

                ForEach(selectedTags.sorted(), id: \.self) { tag in
                    HomeActiveFilterChip(title: "#\(tag)") {
                        onRemoveIncludedTag(tag)
                    }
                }

                ForEach(excludedTags.sorted(), id: \.self) { tag in
                    HomeActiveFilterChip(title: "not #\(tag)", tintColor: .red) {
                        onRemoveExcludedTag(tag)
                    }
                }

                if let selectedPlaceName {
                    HomeActiveFilterChip(
                        title: selectedPlaceName,
                        systemImage: "mappin.and.ellipse",
                        action: onClearPlace
                    )
                }

                if let selectedImportanceUrgencyFilterLabel {
                    HomeActiveFilterChip(
                        title: selectedImportanceUrgencyFilterLabel,
                        systemImage: "square.grid.3x3.topleft.filled",
                        action: onClearImportanceUrgency
                    )
                }

                if let selectedPressureFilter {
                    HomeActiveFilterChip(
                        title: "Pressure \(selectedPressureFilter.title)",
                        systemImage: "brain",
                        action: onClearPressure
                    )
                }

                if hideUnavailableRoutines {
                    HomeActiveFilterChip(
                        title: "Away hidden",
                        systemImage: "location.slash",
                        action: onShowUnavailableRoutines
                    )
                }
            }
        }
    }
}

private struct HomeActiveFilterChip: View {
    let title: String
    let systemImage: String?
    let tintColor: Color
    let action: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        tintColor: Color = .secondary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tintColor = tintColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.caption2)
                }

                Text(title)
                    .font(.caption.weight(.medium))

                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .foregroundStyle(tintColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tintColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
    }
}
