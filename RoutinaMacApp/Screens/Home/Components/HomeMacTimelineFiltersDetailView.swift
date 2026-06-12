import SwiftUI

struct HomeMacTimelineFiltersDetailView: View {
    @Binding var selectedRange: TimelineRange
    @Binding var selectedType: TimelineFilterType
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var selectedMediaFilter: TaskMediaFilter
    let showsTypeSection: Bool
    let importanceUrgencySummary: String
    let allTagsCount: Int
    let availableTags: [String]
    let suggestedRelatedTags: [String]
    let availableExcludeTags: [String]
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludeTagMatchMode: RoutineTagMatchMode
    let selectedExcludedTags: Set<String>
    let tagSelectionSummary: String
    let excludedTagSummary: String
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectSuggestedTag: (String) -> Void
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleExcludedTag: (String) -> Void

    var body: some View {
        Group {
            HomeMacSidebarSectionCard(title: "Range") {
                rangePicker
            }

            if showsTypeSection {
                HomeMacSidebarSectionCard(title: "Type") {
                    typePicker
                }

                HomeMacSidebarSectionCard(title: "Status") {
                    statusPicker
                }
            }

            HomeMacSidebarSectionCard(title: "Importance & Urgency") {
                HomeMacImportanceUrgencyMatrixView(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )
            }

            HomeMacSidebarSectionCard(title: "Media") {
                mediaPicker
            }

            if !availableTags.isEmpty {
                HomeMacSidebarSectionCard(title: "Tags") {
                    HomeMacTimelineTagFiltersView(
                        allTagsCount: allTagsCount,
                        availableTags: availableTags,
                        suggestedRelatedTags: suggestedRelatedTags,
                        availableExcludeTags: availableExcludeTags,
                        selectedTags: selectedTags,
                        includeTagMatchMode: includeTagMatchMode,
                        excludeTagMatchMode: excludeTagMatchMode,
                        selectedExcludedTags: selectedExcludedTags,
                        tagSelectionSummary: tagSelectionSummary,
                        excludedTagSummary: excludedTagSummary,
                        tagCount: tagCount,
                        tagColor: tagColor,
                        onSelectTags: onSelectTags,
                        onIncludeTagMatchModeChange: onIncludeTagMatchModeChange,
                        onSelectSuggestedTag: onSelectSuggestedTag,
                        onExcludeTagMatchModeChange: onExcludeTagMatchModeChange,
                        onToggleExcludedTag: onToggleExcludedTag
                    )
                }
            }
        }
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(TimelineRange.allCases) { range in
                Text(range.rawValue).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    private var typePicker: some View {
        Picker("Type", selection: contentTypeBinding) {
            ForEach(TimelineFilterType.contentTypeCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }

    private var statusPicker: some View {
        Picker("Status", selection: statusBinding) {
            ForEach(TimelineFilterType.statusCases) { status in
                Text(status.rawValue).tag(status)
            }
        }
        .pickerStyle(.segmented)
    }

    private var mediaPicker: some View {
        Picker("Media", selection: $selectedMediaFilter) {
            ForEach(TaskMediaFilter.allCases) { filter in
                Label(filter.title, systemImage: filter.systemImage).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var contentTypeBinding: Binding<TimelineFilterType> {
        Binding(
            get: {
                selectedType.isStatusCase ? .all : selectedType
            },
            set: { selectedType = $0 }
        )
    }

    private var statusBinding: Binding<TimelineFilterType> {
        Binding(
            get: {
                selectedType.isStatusCase ? selectedType : .all
            },
            set: { selectedType = $0 }
        )
    }
}

private extension TimelineFilterType {
    static let contentTypeCases: [TimelineFilterType] = [
        .all,
        .routines,
        .todos,
        .focus,
        .events,
        .emotions,
        .notes,
        .places,
        .sleep,
    ]

    static let statusCases: [TimelineFilterType] = [
        .all,
        .done,
        .missed,
        .canceled,
    ]

    var isStatusCase: Bool {
        Self.statusCases.contains(self) && self != .all
    }
}
