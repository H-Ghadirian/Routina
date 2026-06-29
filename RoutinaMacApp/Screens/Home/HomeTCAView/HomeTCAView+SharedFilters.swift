import SwiftUI

extension HomeTCAView {
    var macSharedFiltersDetailContent: some View {
        let signature = macSharedFiltersPresentationSignature
        let presentation = cachedMacSharedFiltersPresentation(for: signature)

        return HomeMacSharedFiltersDetailView(
            selectedImportanceUrgencyFilter: macSharedImportanceUrgencyFilterBinding,
            importanceUrgencySummary: presentation.importanceUrgencySummary,
            showsTagSection: !presentation.availableTags.isEmpty,
            allTagsCount: presentation.allTagsCount,
            availableTags: presentation.availableTags,
            suggestedRelatedTags: presentation.suggestedRelatedTags,
            availableExcludeTags: presentation.availableExcludeTags,
            selectedTags: presentation.selectedTags,
            includeTagMatchMode: presentation.includeTagMatchMode,
            excludeTagMatchMode: presentation.excludeTagMatchMode,
            selectedExcludedTags: presentation.selectedExcludedTags,
            tagSelectionSummary: presentation.tagSelectionSummary,
            excludedTagSummary: presentation.excludedTagSummary,
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
                guard let mutation = HomeTagFilterMutationSupport.addedIncludedTag(
                    tag,
                    selectedTags: presentation.selectedTags,
                    suggestionAnchor: relatedFilterTagSuggestionAnchor ?? relatedTimelineTagSuggestionAnchor
                ) else { return }
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
            }
        )
        .onAppear {
            refreshMacSharedFiltersPresentationCache(for: signature)
        }
        .onChange(of: signature) { _, newSignature in
            refreshMacSharedFiltersPresentationCache(for: newSignature)
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

    private func cachedMacSharedFiltersPresentation(
        for signature: HomeMacSharedFiltersPresentationSignature
    ) -> HomeMacSharedFiltersPresentation {
        if let cache = macSharedFiltersPresentationCache,
           cache.signature == signature {
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
        let timelineEntries = filteredTimelineEntriesForTagging
        let timelineTagNames = RoutineTag.allTags(from: timelineEntries.map(\.tags))
        let availableTags = macMergedTagList(
            homeData.tagSummaries.map(\.name),
            timelineTagNames
        )
        let selectedTags = macMergedTagSet(
            store.selectedTags,
            store.selectedTimelineTags,
            preferredTags: availableTags
        )
        let selectedExcludedTags = macMergedTagSet(
            store.excludedTags,
            store.selectedTimelineExcludedTags,
            preferredTags: availableTags
        )
        .filter { excludedTag in
            !HomeTagFilterMutationSupport.contains(excludedTag, in: selectedTags)
        }
        let includeMode = store.includeTagMatchMode == store.selectedTimelineIncludeTagMatchMode
            ? store.includeTagMatchMode
            : .all
        let excludeMode = store.excludeTagMatchMode == store.selectedTimelineExcludeTagMatchMode
            ? store.excludeTagMatchMode
            : .any
        let suggestionSource = (relatedFilterTagSuggestionAnchor ?? relatedTimelineTagSuggestionAnchor)
            .map { [$0] } ?? Array(selectedTags)
        let suggestedRelatedTags = selectedTags.isEmpty ? [] : RoutineTagRelations.relatedTags(
            for: suggestionSource,
            rules: store.relatedTagRules,
            availableTags: availableTags
        )

        return HomeMacSharedFiltersPresentation(
            importanceUrgencySummary: macSharedImportanceUrgencySummary,
            allTagsCount: homeData.allTagTaskCount + timelineEntries.count,
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

    private var macSharedFiltersPresentationSignature: HomeMacSharedFiltersPresentationSignature {
        HomeMacSharedFiltersPresentationSignature(
            components: macSharedFilterStateSignature
                + macSharedHomeDisplaySignature
                + macSharedTimelineSourceSignature
        )
    }

    private var macSharedFilterStateSignature: [String] {
        [
            "taskListMode:\(store.taskListMode.rawValue)",
            "taskTags:\(macSignatureString(store.selectedTags))",
            "timelineTags:\(macSignatureString(store.selectedTimelineTags))",
            "taskExcluded:\(macSignatureString(store.excludedTags))",
            "timelineExcluded:\(macSignatureString(store.selectedTimelineExcludedTags))",
            "taskIncludeMode:\(store.includeTagMatchMode.rawValue)",
            "timelineIncludeMode:\(store.selectedTimelineIncludeTagMatchMode.rawValue)",
            "taskExcludeMode:\(store.excludeTagMatchMode.rawValue)",
            "timelineExcludeMode:\(store.selectedTimelineExcludeTagMatchMode.rawValue)",
            "taskPriority:\(macSignatureString(store.selectedImportanceUrgencyFilter))",
            "timelinePriority:\(macSignatureString(store.selectedTimelineImportanceUrgencyFilter))",
            "timelineType:\(store.selectedTimelineFilterType.normalized(includingEventEmotion: areMacEventEmotionActionsEnabled, includingPlaces: isPlacesEnabled, includingNotes: isNotesEnabled, includingAway: isAwayEnabled, includingSleep: includesMacSleepTimelineFilters).rawValue)",
            "timelineMedia:\(store.selectedTimelineMediaFilter.rawValue)",
            "eventsEmotions:\(areMacEventEmotionActionsEnabled)",
            "places:\(isPlacesEnabled)",
            "notes:\(isNotesEnabled)",
            "away:\(isAwayEnabled)",
            "sleep:\(includesMacSleepTimelineFilters)",
            "filterAnchor:\(relatedFilterTagSuggestionAnchor ?? "")",
            "timelineAnchor:\(relatedTimelineTagSuggestionAnchor ?? "")",
            "tagColors:\(macSignatureString(store.tagColors))",
            "relatedRules:\(macRelatedTagRulesSignature)",
            "fileAttachments:\(macSignatureString(store.fileAttachmentTaskIDs))",
            "noteAttachments:\(macSignatureString(Set(noteAttachments.map(\.noteID))))",
        ]
    }

    private var macSharedHomeDisplaySignature: [String] {
        (store.routineDisplays + store.awayRoutineDisplays + store.archivedRoutineDisplays)
            .map { display in
                [
                    "home",
                    display.taskID.uuidString,
                    display.isOneOffTask.description,
                    macSignatureString(display.tags),
                    display.importance.rawValue,
                    display.urgency.rawValue,
                ].joined(separator: "|")
            }
            .sorted()
    }

    private var macSharedTimelineSourceSignature: [String] {
        var components: [String] = []

        components += store.routineTasks.map { task in
            [
                "task",
                task.id.uuidString,
                task.tagsStorage,
                task.importanceRawValue,
                task.urgencyRawValue,
                task.scheduleModeRawValue,
                task.lastDone?.timeIntervalSinceReferenceDate.description ?? "",
                task.canceledAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += store.timelineLogs.map { log in
            [
                "log",
                log.id.uuidString,
                log.taskID.uuidString,
                log.timestamp?.timeIntervalSinceReferenceDate.description ?? "",
                log.kindRawValue,
            ].joined(separator: "|")
        }

        components += events.map { event in
            [
                "event",
                event.id.uuidString,
                event.tagsStorage,
                event.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                event.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                event.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += emotionLogs.map { emotion in
            [
                "emotion",
                emotion.id.uuidString,
                emotion.createdAt?.timeIntervalSinceReferenceDate.description ?? "",
                emotion.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
                emotion.linkedTaskID?.uuidString ?? "",
                emotion.linkedSleepSessionID?.uuidString ?? "",
            ].joined(separator: "|")
        }

        components += notes.map { note in
            [
                "note",
                note.id.uuidString,
                note.tagsStorage,
                note.createdAt?.timeIntervalSinceReferenceDate.description ?? "",
                note.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += focusSessions.map { session in
            [
                "focus",
                session.id.uuidString,
                session.taskID.uuidString,
                session.tagName ?? "",
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.completedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.abandonedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += sprintFocusSessions.map { session in
            [
                "sprintFocus",
                session.id.uuidString,
                session.startedAt.timeIntervalSinceReferenceDate.description,
                session.stoppedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.pausedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += boardSprints.map { sprint in
            [
                "boardSprint",
                sprint.id.uuidString,
                sprint.createdAt.timeIntervalSinceReferenceDate.description,
                sprint.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                sprint.finishedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += sleepSessions.map { session in
            [
                "sleep",
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += awaySessions.map { session in
            [
                "away",
                session.id.uuidString,
                session.linkedTaskID?.uuidString ?? "",
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.completedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedEarlyAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        components += placeCheckInSessions.map { session in
            [
                "place",
                session.id.uuidString,
                session.startedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.endedAt?.timeIntervalSinceReferenceDate.description ?? "",
                session.updatedAt?.timeIntervalSinceReferenceDate.description ?? "",
            ].joined(separator: "|")
        }

        return components.sorted()
    }

    private var macRelatedTagRulesSignature: String {
        store.relatedTagRules
            .map { rule in
                "\(rule.id):\(macSignatureString(rule.relatedTags))"
            }
            .sorted()
            .joined(separator: ";")
    }

    private var macSharedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? {
        let taskFilter = ImportanceUrgencyFilterCell.normalized(store.selectedImportanceUrgencyFilter)
        let timelineFilter = ImportanceUrgencyFilterCell.normalized(store.selectedTimelineImportanceUrgencyFilter)
        guard taskFilter != timelineFilter else { return taskFilter }
        return taskFilter ?? timelineFilter
    }

    private var macSharedImportanceUrgencySummary: String {
        guard let filter = macSharedImportanceUrgencyFilter else {
            return "Showing tasks and done items across all importance and urgency levels."
        }
        return "Showing tasks and done items with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
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
                  let color = summary.displayColor else { continue }
            colors[key] = color
        }

        for tag in availableTags {
            guard let key = RoutineTag.normalized(tag), colors[key] == nil else { continue }
            colors[key] = Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: store.tagColors))
        }

        return colors
    }

    private func macMergedTagSet(_ sets: Set<String>..., preferredTags: [String]) -> Set<String> {
        Set(RoutineTag.deduplicated(sets.flatMap { Array($0) }, preferredTags: preferredTags))
    }

    private func macMergedTagList(_ lists: [String]...) -> [String] {
        RoutineTag.deduplicated(lists.flatMap { $0 })
            .sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
    }

    private func macSignatureString(_ values: [String]) -> String {
        values.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        .joined(separator: ",")
    }

    private func macSignatureString(_ values: Set<String>) -> String {
        macSignatureString(Array(values))
    }

    private func macSignatureString(_ values: Set<UUID>) -> String {
        values
            .map(\.uuidString)
            .sorted()
            .joined(separator: ",")
    }

    private func macSignatureString(_ values: [String: String]) -> String {
        values
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: ",")
    }

    private func macSignatureString(_ filter: ImportanceUrgencyFilterCell?) -> String {
        guard let filter = ImportanceUrgencyFilterCell.normalized(filter) else { return "" }
        return "\(filter.importance.rawValue):\(filter.urgency.rawValue)"
    }
}

struct HomeMacSharedFiltersPresentationCache {
    let signature: HomeMacSharedFiltersPresentationSignature
    let presentation: HomeMacSharedFiltersPresentation
}

struct HomeMacSharedFiltersPresentationSignature: Hashable {
    let components: [String]
}

struct HomeMacSharedFiltersPresentation {
    let importanceUrgencySummary: String
    let allTagsCount: Int
    let availableTags: [String]
    let availableExcludeTags: [String]
    let suggestedRelatedTags: [String]
    let selectedTags: Set<String>
    let selectedExcludedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let excludeTagMatchMode: RoutineTagMatchMode
    let tagCountsByNormalizedName: [String: Int]
    let tagColorsByNormalizedName: [String: Color]

    var tagSelectionSummary: String {
        guard !selectedTags.isEmpty else {
            let count = availableTags.count
            return "\(count) \(count == 1 ? "tag" : "tags") available"
        }

        return "\(includeTagMatchMode.rawValue) of \(selectedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
    }

    var excludedTagSummary: String {
        guard !selectedExcludedTags.isEmpty else {
            return "Select tags to hide tasks and done items that have them."
        }

        return "Hiding items tagged: \(selectedExcludedTags.sorted().map { "#\($0)" }.joined(separator: ", "))"
    }

    func tagCount(for tag: String) -> Int {
        guard let key = RoutineTag.normalized(tag) else { return 0 }
        return tagCountsByNormalizedName[key, default: 0]
    }

    func tagColor(for tag: String) -> Color? {
        guard let key = RoutineTag.normalized(tag) else { return nil }
        return tagColorsByNormalizedName[key]
    }
}

private struct HomeMacSharedFiltersDetailView: View {
    @Binding var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let importanceUrgencySummary: String
    let showsTagSection: Bool
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
            HomeMacImportanceUrgencyDisclosureSection(
                selectedFilter: $selectedImportanceUrgencyFilter,
                summaryText: importanceUrgencySummary
            )

            if showsTagSection {
                HomeMacCollapsibleFilterSection(
                    title: "Tags",
                    summaryText: tagsSummary,
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

    private var tagsSummary: String {
        if !selectedTags.isEmpty {
            return tagSelectionSummary
        }

        if !selectedExcludedTags.isEmpty {
            return excludedTagSummary
        }

        return "\(availableTags.count) available tags"
    }
}
