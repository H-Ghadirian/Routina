import SwiftUI

struct HomeMacTimelineFiltersDetailView: View {
    @Binding var selectedRange: TimelineRange
    @Binding var selectedType: TimelineFilterType
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let showsTypeSection: Bool
    let importanceUrgencySummary: String
    let allTagsCount: Int
    let availableTags: [String]
    let availableExcludeTags: [String]
    let selectedTag: String?
    let selectedExcludedTags: Set<String>
    let tagSelectionSummary: String
    let excludedTagSummary: String
    let tagCount: (String) -> Int
    let onSelectTag: (String?) -> Void
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
            }

            HomeMacSidebarSectionCard(title: "Importance & Urgency") {
                HomeMacImportanceUrgencyMatrixView(
                    selectedFilter: $selectedImportanceUrgencyFilter,
                    summaryText: importanceUrgencySummary
                )
            }

            if !availableTags.isEmpty {
                HomeMacSidebarSectionCard(title: "Tags") {
                    HomeMacTimelineTagFiltersView(
                        allTagsCount: allTagsCount,
                        availableTags: availableTags,
                        availableExcludeTags: availableExcludeTags,
                        selectedTag: selectedTag,
                        selectedExcludedTags: selectedExcludedTags,
                        tagSelectionSummary: tagSelectionSummary,
                        excludedTagSummary: excludedTagSummary,
                        tagCount: tagCount,
                        onSelectTag: onSelectTag,
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
        Picker("Type", selection: $selectedType) {
            ForEach(TimelineFilterType.allCases) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
    }
}
