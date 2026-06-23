import SwiftUI

struct HomeMacTimelineFiltersDetailView: View {
    @State private var selectedTab: HomeMacTimelineFilterDetailTab = .filter

    @Binding var selectedRange: TimelineRange
    @Binding var selectedType: TimelineFilterType
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var selectedMediaFilter: TaskMediaFilter
    let timelineRowVisibility: HomeTimelineRowVisibility
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
    let onTimelineRowFieldVisibilityChanged: (HomeTimelineRowField, Bool) -> Void
    let includesEventEmotionFilters: Bool
    let includesPlaceFilters: Bool

    var body: some View {
        Group {
            tabPicker

            switch selectedTab {
            case .filter:
                filterTabContent
            case .appearance:
                appearanceTabContent
            }
        }
    }

    private var tabPicker: some View {
        HomeMacTimelineFilterDetailTabStrip(selection: $selectedTab)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var filterTabContent: some View {
        Group {
            HomeMacSidebarSectionCard {
                VStack(alignment: .leading, spacing: 18) {
                    filterControlSection("Range") {
                        rangePicker
                    }

                    if showsTypeSection {
                        filterControlSection("Type") {
                            typePicker
                        }

                        filterControlSection("Status") {
                            statusPicker
                        }
                    }

                    filterControlSection("Media") {
                        mediaPicker
                    }
                }
            }

            HomeMacImportanceUrgencyDisclosureSection(
                selectedFilter: $selectedImportanceUrgencyFilter,
                summaryText: importanceUrgencySummary
            )

            if !availableTags.isEmpty {
                HomeMacCollapsibleFilterSection(
                    title: "Tags",
                    summaryText: timelineTagsSummary,
                    systemImage: "tag.fill",
                    tint: .teal
                ) {
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

    private var appearanceTabContent: some View {
        HomeMacSidebarSectionCard(title: "Timeline Row") {
            ForEach(HomeTimelineRowField.allCases) { field in
                Toggle(isOn: timelineRowFieldVisibilityBinding(field)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(field.title)
                        Text(field.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Text("Shown: \(macTimelineRowSummaryText)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func filterControlSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private var timelineTagsSummary: String {
        if !selectedTags.isEmpty {
            return tagSelectionSummary
        }

        if !selectedExcludedTags.isEmpty {
            return excludedTagSummary
        }

        return "\(availableTags.count) available tags"
    }

    private var rangePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Range",
            options: TimelineRange.allCases,
            selection: $selectedRange
        ) { range in
            Text(range.rawValue)
        }
    }

    private var typePicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Type",
            options: TimelineFilterType.visibleContentTypeCases(
                includingEventEmotion: includesEventEmotionFilters,
                includingPlaces: includesPlaceFilters
            ),
            selection: contentTypeBinding
        ) { type in
            Text(type.rawValue)
        }
    }

    private var statusPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Status",
            options: TimelineFilterType.statusCases,
            selection: statusBinding
        ) { status in
            Text(status.rawValue)
        }
    }

    private var mediaPicker: some View {
        RoutinaGlassSegmentedControl(
            accessibilityLabel: "Media",
            options: TaskMediaFilter.allCases,
            selection: $selectedMediaFilter
        ) { filter in
            Text(filter.title)
        }
    }

    private var contentTypeBinding: Binding<TimelineFilterType> {
        Binding(
            get: {
                selectedType.isStatusCase
                    ? .all
                    : selectedType.normalized(
                        includingEventEmotion: includesEventEmotionFilters,
                        includingPlaces: includesPlaceFilters
                    )
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

    private func timelineRowFieldVisibilityBinding(_ field: HomeTimelineRowField) -> Binding<Bool> {
        Binding(
            get: { timelineRowVisibility.shows(field) },
            set: { onTimelineRowFieldVisibilityChanged(field, $0) }
        )
    }

    private var macTimelineRowSummaryText: String {
        let hiddenCount = HomeTimelineRowField.allCases.filter {
            !timelineRowVisibility.shows($0)
        }.count
        guard hiddenCount > 0 else { return "All fields" }
        return "\(HomeTimelineRowField.allCases.count - hiddenCount) of \(HomeTimelineRowField.allCases.count) fields"
    }
}

private struct HomeMacTimelineFilterDetailTabStrip: View {
    @Binding var selection: HomeMacTimelineFilterDetailTab
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(HomeMacTimelineFilterDetailTab.allCases) { tab in
                    segmentButton(for: tab)
                }
            }
            .padding(5)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        .frame(width: 420)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timeline tabs")
    }

    private func segmentButton(for tab: HomeMacTimelineFilterDetailTab) -> some View {
        let isSelected = selection == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = tab
            }
        } label: {
            Text(tab.title)
                .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .glassEffect(
                        .regular.tint(Color.accentColor.opacity(0.34)).interactive(),
                        in: .rect(cornerRadius: 11)
                    )
                    .glassEffectID("HomeMacTimelineFilterDetailTabSelection", in: glassNamespace)
            }
        }
        .accessibilityLabel(tab.title)
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

private enum HomeMacTimelineFilterDetailTab: String, CaseIterable, Identifiable {
    case filter
    case appearance

    var id: Self { self }

    var title: String {
        switch self {
        case .filter: return "Filter"
        case .appearance: return "Appearance"
        }
    }
}
