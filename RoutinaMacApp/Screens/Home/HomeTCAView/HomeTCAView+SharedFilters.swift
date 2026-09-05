import SwiftUI

extension HomeTCAView {
    var macSharedFiltersDetailContent: some View {
        let signature = macSharedFiltersPresentationSignature
        let presentation = cachedMacSharedFiltersPresentation(for: signature)

        return HomeMacSharedFiltersDetailView(
            selectedImportanceUrgencyFilter: macSharedImportanceUrgencyFilterBinding,
            selectedPressureFilter: macSharedPressureFilterBinding,
            selectedThinkingNeededFilter: macSharedThinkingNeededFilterBinding,
            selectedEstimationFilter: macSharedEstimationFilterBinding,
            showsFlagSection: !presentation.availableFlags.isEmpty
                || !presentation.selectedFlags.isEmpty
                || !presentation.excludedFlags.isEmpty,
            availableFlags: presentation.availableFlags,
            selectedFlags: presentation.selectedFlags,
            excludedFlags: presentation.excludedFlags,
            includeFlagMatchMode: presentation.includeFlagMatchMode,
            excludeFlagMatchMode: presentation.excludeFlagMatchMode,
            showsTagSection: !presentation.availableTags.isEmpty
                || !presentation.selectedTags.isEmpty
                || !presentation.selectedExcludedTags.isEmpty,
            availableTags: presentation.availableTags,
            suggestedRelatedTags: presentation.suggestedRelatedTags,
            availableExcludeTags: presentation.availableExcludeTags,
            selectedTags: presentation.selectedTags,
            includeTagMatchMode: presentation.includeTagMatchMode,
            excludeTagMatchMode: presentation.excludeTagMatchMode,
            selectedExcludedTags: presentation.selectedExcludedTags,
            tagCount: { tag in
                presentation.tagCount(for: tag)
            },
            tagColor: { tag in
                presentation.tagColor(for: tag)
            },
            onSelectTags: { tags in
                applyMacSharedTags(
                    selectedTags: tags,
                    excludedTags: presentation.selectedExcludedTags,
                    preferredTags: presentation.availableTags
                )
            },
            onIncludeTagMatchModeChange: { mode in
                store.send(.includeTagMatchModeChanged(mode))
                store.send(.selectedTimelineIncludeTagMatchModeChanged(mode))
            },
            onSelectSuggestedTag: { tag in
                guard
                    let mutation = HomeTagFilterMutationSupport.addedIncludedTag(
                        tag,
                        selectedTags: presentation.selectedTags,
                        suggestionAnchor: relatedFilterTagSuggestionAnchor ?? relatedTimelineTagSuggestionAnchor
                    )
                else { return }
                applyMacSharedTags(
                    selectedTags: mutation.selectedTags,
                    excludedTags: presentation.selectedExcludedTags,
                    suggestionAnchor: mutation.suggestionAnchor,
                    preferredTags: presentation.availableTags
                )
            },
            onExcludeTagMatchModeChange: { mode in
                store.send(.excludeTagMatchModeChanged(mode))
                store.send(.selectedTimelineExcludeTagMatchModeChanged(mode))
            },
            onToggleExcludedTag: { tag in
                let mutation = HomeTagFilterMutationSupport.toggledExcludedTag(
                    tag,
                    selectedTags: presentation.selectedTags,
                    excludedTags: presentation.selectedExcludedTags
                )
                applyMacSharedTags(
                    selectedTags: mutation.selectedTags,
                    excludedTags: mutation.excludedTags,
                    preferredTags: presentation.availableTags
                )
            },
            onSelectIncludedFlags: { flags in
                applyMacSharedFlags(
                    selectedFlags: flags,
                    excludedFlags: presentation.excludedFlags,
                    preferredFlags: presentation.availableFlags
                )
            },
            onIncludeFlagMatchModeChange: { mode in
                store.send(.includeFlagMatchModeChanged(mode))
                store.send(.selectedTimelineIncludeFlagMatchModeChanged(mode))
            },
            onSelectExcludedFlags: { flags in
                applyMacSharedFlags(
                    selectedFlags: presentation.selectedFlags,
                    excludedFlags: flags,
                    preferredFlags: presentation.availableFlags
                )
            },
            onExcludeFlagMatchModeChange: { mode in
                store.send(.excludeFlagMatchModeChanged(mode))
            }
        )
        .onAppear {
            refreshMacSharedFiltersPresentationCache(for: signature)
            synchronizeMacSharedFilters(preferredTags: presentation.availableTags)
        }
        .onChange(of: signature) { _, newSignature in
            refreshMacSharedFiltersPresentationCache(for: newSignature)
            let updatedPresentation = cachedMacSharedFiltersPresentation(for: newSignature)
            synchronizeMacSharedFilters(preferredTags: updatedPresentation.availableTags)
        }
    }

    private var macSharedImportanceUrgencyFilterBinding: Binding<ImportanceUrgencyFilterCell?> {
        Binding(
            get: { macSharedImportanceUrgencyFilter },
            set: { filter in
                store.send(.selectedImportanceUrgencyFilterChanged(filter))
                store.send(.selectedTimelineImportanceUrgencyFilterChanged(filter))
            }
        )
    }

    private var macSharedPressureFilterBinding: Binding<RoutineTaskPressure?> {
        Binding(
            get: { macSharedFilterState(preferredTags: []).selectedPressureFilter },
            set: { filter in
                store.send(.selectedPressureFilterChanged(filter))
                store.send(.selectedTimelinePressureFilterChanged(filter))
            }
        )
    }

    private var macSharedThinkingNeededFilterBinding: Binding<RoutineTaskThinkingNeeded?> {
        Binding(
            get: { macSharedFilterState(preferredTags: []).selectedThinkingNeededFilter },
            set: { filter in
                store.send(.selectedThinkingNeededFilterChanged(filter))
                store.send(.selectedTimelineThinkingNeededFilterChanged(filter))
            }
        )
    }

    private var macSharedEstimationFilterBinding: Binding<TaskEstimationFilter> {
        Binding(
            get: { macSharedFilterState(preferredTags: []).selectedEstimationFilter },
            set: { filter in
                store.send(.selectedEstimationFilterChanged(filter))
                store.send(.selectedTimelineEstimationFilterChanged(filter))
            }
        )
    }

    private func cachedMacSharedFiltersPresentation(
        for signature: HomeMacSharedFiltersPresentationSignature
    ) -> HomeMacSharedFiltersPresentation {
        if let cache = macSharedFiltersPresentationCache,
            cache.signature == signature
        {
            return cache.presentation
        }

        return makeMacSharedFiltersPresentation()
    }

    private func refreshMacSharedFiltersPresentationCache(
        for signature: HomeMacSharedFiltersPresentationSignature
    ) {
        guard macSharedFiltersPresentationCache?.signature != signature else { return }
        macSharedFiltersPresentationCache = HomeMacSharedFiltersPresentationCache(
            signature: signature,
            presentation: makeMacSharedFiltersPresentation()
        )
    }

    private func makeMacSharedFiltersPresentation() -> HomeMacSharedFiltersPresentation {
        let homeData = homeTagFilterData
        let homeFlagData = homeFlagFilterData
        let timelineEntries = filteredTimelineEntriesForTagging
        let timelineTagNames = RoutineTag.allTags(from: timelineEntries.map(\.tags))
        let availableTags = macMergedTagList(
            homeData.tagSummaries.map(\.name),
            timelineTagNames
        )
        let sharedFilterState = macSharedFilterState(preferredTags: availableTags)
        let availableFlags = macMergedFlagList(
            homeFlagData.flagOptions.map(\.name),
            availableTimelineFlags,
            Array(sharedFilterState.selectedFlags),
            Array(sharedFilterState.excludedFlags)
        )
        let selectedTags = sharedFilterState.selectedTags
        let selectedExcludedTags = sharedFilterState.excludedTags
        let includeMode = sharedFilterState.includeTagMatchMode
        let excludeMode = sharedFilterState.excludeTagMatchMode
        let suggestionSource =
            (relatedFilterTagSuggestionAnchor ?? relatedTimelineTagSuggestionAnchor)
            .map { [$0] } ?? Array(selectedTags)
        let suggestedRelatedTags =
            selectedTags.isEmpty
            ? []
            : RoutineTagRelations.relatedTags(
                for: suggestionSource,
                rules: store.relatedTagRules,
                availableTags: availableTags
            )

        return HomeMacSharedFiltersPresentation(
            availableFlags: availableFlags,
            selectedFlags: sharedFilterState.selectedFlags,
            excludedFlags: sharedFilterState.excludedFlags,
            includeFlagMatchMode: sharedFilterState.includeFlagMatchMode,
            excludeFlagMatchMode: sharedFilterState.excludeFlagMatchMode,
            availableTags: availableTags,
            availableExcludeTags: HomeTagFilterMutationSupport.availableExcludeTags(
                from: availableTags,
                selectedTags: selectedTags
            ),
            suggestedRelatedTags: suggestedRelatedTags,
            selectedTags: selectedTags,
            selectedExcludedTags: selectedExcludedTags,
            includeTagMatchMode: includeMode,
            excludeTagMatchMode: excludeMode,
            tagCountsByNormalizedName: macSharedTagCounts(
                homeData: homeData,
                timelineEntries: timelineEntries
            ),
            tagColorsByNormalizedName: macSharedTagColors(homeData: homeData, availableTags: availableTags)
        )
    }

    private var macSharedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? {
        macSharedFilterState(preferredTags: []).selectedImportanceUrgencyFilter
    }

    var macSharedSelectedFlags: Set<String> {
        macSharedFilterState(preferredTags: []).selectedFlags
    }

    var macSharedExcludedFlags: Set<String> {
        macSharedFilterState(preferredTags: []).excludedFlags
    }

    var macSharedIncludeFlagMatchMode: RoutineTagMatchMode {
        macSharedFilterState(preferredTags: []).includeFlagMatchMode
    }

    var macSharedExcludeFlagMatchMode: RoutineTagMatchMode {
        macSharedFilterState(preferredTags: []).excludeFlagMatchMode
    }

    private func synchronizeMacSharedFilters(preferredTags: [String]) {
        let sharedState = macSharedFilterState(preferredTags: preferredTags)

        if store.selectedTags != sharedState.selectedTags {
            store.send(.selectedTagsChanged(sharedState.selectedTags))
        }
        if store.selectedTimelineTags != sharedState.selectedTags {
            store.send(.selectedTimelineTagsChanged(sharedState.selectedTags))
        }
        if store.excludedTags != sharedState.excludedTags {
            store.send(.excludedTagsChanged(sharedState.excludedTags))
        }
        if store.selectedTimelineExcludedTags != sharedState.excludedTags {
            store.send(.selectedTimelineExcludedTagsChanged(sharedState.excludedTags))
        }
        if store.includeTagMatchMode != sharedState.includeTagMatchMode {
            store.send(.includeTagMatchModeChanged(sharedState.includeTagMatchMode))
        }
        if store.selectedTimelineIncludeTagMatchMode != sharedState.includeTagMatchMode {
            store.send(.selectedTimelineIncludeTagMatchModeChanged(sharedState.includeTagMatchMode))
        }
        if store.excludeTagMatchMode != sharedState.excludeTagMatchMode {
            store.send(.excludeTagMatchModeChanged(sharedState.excludeTagMatchMode))
        }
        if store.selectedTimelineExcludeTagMatchMode != sharedState.excludeTagMatchMode {
            store.send(.selectedTimelineExcludeTagMatchModeChanged(sharedState.excludeTagMatchMode))
        }
        if store.selectedFlags != sharedState.selectedFlags {
            store.send(.selectedFlagsChanged(sharedState.selectedFlags))
        }
        if store.selectedTimelineFlags != sharedState.selectedFlags {
            store.send(.selectedTimelineFlagsChanged(sharedState.selectedFlags))
        }
        if store.excludedFlags != sharedState.excludedFlags {
            store.send(.excludedFlagsChanged(sharedState.excludedFlags))
        }
        if store.includeFlagMatchMode != sharedState.includeFlagMatchMode {
            store.send(.includeFlagMatchModeChanged(sharedState.includeFlagMatchMode))
        }
        if store.selectedTimelineIncludeFlagMatchMode != sharedState.includeFlagMatchMode {
            store.send(.selectedTimelineIncludeFlagMatchModeChanged(sharedState.includeFlagMatchMode))
        }
        if store.excludeFlagMatchMode != sharedState.excludeFlagMatchMode {
            store.send(.excludeFlagMatchModeChanged(sharedState.excludeFlagMatchMode))
        }

        let taskFilter = ImportanceUrgencyFilterCell.normalized(store.selectedImportanceUrgencyFilter)
        let timelineFilter = ImportanceUrgencyFilterCell.normalized(store.selectedTimelineImportanceUrgencyFilter)
        if taskFilter != sharedState.selectedImportanceUrgencyFilter {
            store.send(.selectedImportanceUrgencyFilterChanged(sharedState.selectedImportanceUrgencyFilter))
        }
        if timelineFilter != sharedState.selectedImportanceUrgencyFilter {
            store.send(.selectedTimelineImportanceUrgencyFilterChanged(sharedState.selectedImportanceUrgencyFilter))
        }
        if store.selectedPressureFilter != sharedState.selectedPressureFilter {
            store.send(.selectedPressureFilterChanged(sharedState.selectedPressureFilter))
        }
        if store.selectedTimelinePressureFilter != sharedState.selectedPressureFilter {
            store.send(.selectedTimelinePressureFilterChanged(sharedState.selectedPressureFilter))
        }
        if store.selectedThinkingNeededFilter != sharedState.selectedThinkingNeededFilter {
            store.send(.selectedThinkingNeededFilterChanged(sharedState.selectedThinkingNeededFilter))
        }
        if store.selectedTimelineThinkingNeededFilter != sharedState.selectedThinkingNeededFilter {
            store.send(.selectedTimelineThinkingNeededFilterChanged(sharedState.selectedThinkingNeededFilter))
        }
        if store.selectedEstimationFilter != sharedState.selectedEstimationFilter {
            store.send(.selectedEstimationFilterChanged(sharedState.selectedEstimationFilter))
        }
        if store.selectedTimelineEstimationFilter != sharedState.selectedEstimationFilter {
            store.send(.selectedTimelineEstimationFilterChanged(sharedState.selectedEstimationFilter))
        }
    }

    private func applyMacSharedTags(
        selectedTags rawSelectedTags: Set<String>,
        excludedTags rawExcludedTags: Set<String>? = nil,
        suggestionAnchor: String? = nil,
        preferredTags: [String]
    ) {
        let selectedTags = macMergedTagSet(rawSelectedTags, preferredTags: preferredTags)
        let excludedTags = macMergedTagSet(rawExcludedTags ?? [], preferredTags: preferredTags)
            .filter { excludedTag in
                !HomeTagFilterMutationSupport.contains(excludedTag, in: selectedTags)
            }
        let resolvedSuggestionAnchor = suggestionAnchor ?? selectedTags.sorted().last

        relatedFilterTagSuggestionAnchor = resolvedSuggestionAnchor
        relatedTimelineTagSuggestionAnchor = resolvedSuggestionAnchor
        store.send(.selectedTagsChanged(selectedTags))
        store.send(.selectedTimelineTagsChanged(selectedTags))
        store.send(.excludedTagsChanged(excludedTags))
        store.send(.selectedTimelineExcludedTagsChanged(excludedTags))
    }

    private func applyMacSharedFlags(
        selectedFlags rawSelectedFlags: Set<String>,
        excludedFlags rawExcludedFlags: Set<String>,
        preferredFlags: [String]
    ) {
        var selectedFlags = macMergedFlagSet(rawSelectedFlags, preferredFlags: preferredFlags)
        let excludedFlags = macMergedFlagSet(rawExcludedFlags, preferredFlags: preferredFlags)

        selectedFlags = selectedFlags.filter { selectedFlag in
            !HomeFlagFilterMutationSupport.contains(selectedFlag, in: excludedFlags)
        }

        store.send(.selectedFlagsChanged(selectedFlags))
        store.send(.selectedTimelineFlagsChanged(selectedFlags))
        store.send(.excludedFlagsChanged(excludedFlags))
    }

    private func macSharedTagCounts(
        homeData: HomeTagFilterData,
        timelineEntries: [TimelineEntry]
    ) -> [String: Int] {
        var counts: [String: Int] = [:]

        for summary in homeData.tagSummaries {
            guard let key = RoutineTag.normalized(summary.name) else { continue }
            counts[key, default: 0] += summary.linkedRoutineCount
        }

        for entry in timelineEntries {
            for tag in entry.tags {
                guard let key = RoutineTag.normalized(tag) else { continue }
                counts[key, default: 0] += 1
            }
        }

        return counts
    }

    private func macSharedTagColors(
        homeData: HomeTagFilterData,
        availableTags: [String]
    ) -> [String: Color] {
        var colors: [String: Color] = [:]

        for summary in homeData.tagSummaries + homeData.availableExcludeTagSummaries {
            guard let key = RoutineTag.normalized(summary.name),
                let color = summary.displayColor
            else { continue }
            colors[key] = color
        }

        for tag in availableTags {
            guard let key = RoutineTag.normalized(tag), colors[key] == nil else { continue }
            colors[key] = Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: store.tagColors))
        }

        return colors
    }

}

private struct HomeMacSharedFiltersDetailView: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    @Binding var selectedPressureFilter: RoutineTaskPressure?
    @Binding var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded?
    @Binding var selectedEstimationFilter: TaskEstimationFilter
    let showsFlagSection: Bool
    let availableFlags: [String]
    let selectedFlags: Set<String>
    let excludedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludeFlagMatchMode: RoutineTagMatchMode
    let showsTagSection: Bool
    let availableTags: [String]
    let suggestedRelatedTags: [String]
    let availableExcludeTags: [String]
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludeTagMatchMode: RoutineTagMatchMode
    let selectedExcludedTags: Set<String>
    let tagCount: (String) -> Int
    let tagColor: (String) -> Color?
    let onSelectTags: (Set<String>) -> Void
    let onIncludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectSuggestedTag: (String) -> Void
    let onExcludeTagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onToggleExcludedTag: (String) -> Void
    let onSelectIncludedFlags: (Set<String>) -> Void
    let onIncludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void
    let onSelectExcludedFlags: (Set<String>) -> Void
    let onExcludeFlagMatchModeChange: (RoutineTagMatchMode) -> Void

    var body: some View {
        Group {
            HomeMacTaskLadderFiltersSection(
                selectedImportanceUrgencyFilter: $selectedImportanceUrgencyFilter,
                selectedPressureFilter: $selectedPressureFilter,
                selectedThinkingNeededFilter: $selectedThinkingNeededFilter,
                selectedEstimationFilter: $selectedEstimationFilter
            )

            if showsFlagSection {
                HomeMacSharedFlagFiltersView(
                    availableFlags: availableFlags,
                    selectedFlags: selectedFlags,
                    excludedFlags: excludedFlags,
                    includeFlagMatchMode: includeFlagMatchMode,
                    excludeFlagMatchMode: excludeFlagMatchMode,
                    onSelectIncludedFlags: onSelectIncludedFlags,
                    onIncludeFlagMatchModeChange: onIncludeFlagMatchModeChange,
                    onSelectExcludedFlags: onSelectExcludedFlags,
                    onExcludeFlagMatchModeChange: onExcludeFlagMatchModeChange
                )
            }

            if showsTagSection {
                HomeMacTimelineTagFiltersView(
                    availableTags: availableTags,
                    suggestedRelatedTags: suggestedRelatedTags,
                    availableExcludeTags: availableExcludeTags,
                    selectedTags: selectedTags,
                    includeTagMatchMode: includeTagMatchMode,
                    excludeTagMatchMode: excludeTagMatchMode,
                    selectedExcludedTags: selectedExcludedTags,
                    tagCount: tagCount,
                    tagColor: tagColor,
                    onSelectTags: onSelectTags,
                    onIncludeTagMatchModeChange: onIncludeTagMatchModeChange,
                    onSelectSuggestedTag: onSelectSuggestedTag,
                    onExcludeTagMatchModeChange: onExcludeTagMatchModeChange,
                    onToggleExcludedTag: onToggleExcludedTag,
                    presentation: .compactActions
                )
            }
        }
    }
}
