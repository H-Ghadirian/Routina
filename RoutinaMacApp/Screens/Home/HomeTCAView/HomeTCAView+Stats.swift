import SwiftUI

extension HomeTCAView {
    @ViewBuilder
    var macProgressSidebarView: some View {
        if isMacAdventureMode {
            HomeMacAdventureSidebarView(progression: homeAdventureProgression)
        } else {
            macStatsSidebarView
        }
    }

    var homeAdventureProgression: HomeAdventureProgression {
        HomeAdventureProgressionBuilder.build(
            tasks: store.routineTasks,
            logs: store.timelineLogs,
            focusSessions: focusSessions,
            sprintFocusSessions: sprintFocusSessions,
            sleepSessions: isAwayEnabled ? sleepSessions : [],
            awaySessions: isAwayEnabled ? awaySessions : [],
            dayPlanBlocks: dayPlanBlocks,
            emotionLogs: emotionLogs,
            notes: isNotesEnabled ? notes : [],
            events: events,
            goals: store.routineGoals,
            placeCheckInSessions: isPlacesEnabled ? placeCheckInSessions : [],
            referenceDate: Date(),
            calendar: calendar
        )
    }

    var macStatsSidebarView: some View {
        let filterPresentation = statsFilterPresentation
        let statsTasks = statsStore?.tasks ?? store.routineTasks
        let allTags = statsAllTags
        let tagSummaries = statsStore?.tagSummaries ?? filterPresentation.tagSummaries(from: statsTasks)
        let taskCountForSelectedTypeFilter = statsStore?.taskCountForSelectedTypeFilter
            ?? filterPresentation.taskCountForSelectedTypeFilter(in: statsTasks)
        let availableExcludeTags = statsStore?.availableExcludeTags
            ?? filterPresentation.availableExcludeTags(from: statsTasks)
        let tagCountsByNormalizedName = Dictionary(
            uniqueKeysWithValues: tagSummaries.compactMap { summary in
                RoutineTag.normalized(summary.name).map { ($0, summary.linkedRoutineCount) }
            }
        )

        return HomeMacStatsSidebarView(
            selectedTaskTypeFilter: statsStore?.taskTypeFilter ?? .all,
            onSelectTaskTypeFilter: { filter in
                statsStore?.send(.taskTypeFilterChanged(filter))
            },
            availableDashboardScopes: availableStatsDashboardScopes,
            selectedDashboardScope: resolvedStatsDashboardScope,
            onSelectDashboardScope: { selected in
                selectedStatsDashboardScope = selected
            },
            selectedRange: statsStore?.selectedRange ?? .week,
            onSelectRange: { range in
                statsStore?.send(.selectedRangeChanged(range))
            },
            advancedQuery: Binding(
                get: { statsStore?.advancedQuery ?? "" },
                set: { statsStore?.send(.advancedQueryChanged($0)) }
            ),
            queryOptions: HomeAdvancedQueryOptions(
                tags: allTags,
                places: []
            ),
            selectedImportanceUrgencyFilter: Binding(
                get: { statsStore?.selectedImportanceUrgencyFilter },
                set: { statsStore?.send(.selectedImportanceUrgencyFilterChanged($0)) }
            ),
            importanceUrgencySummary: statsImportanceUrgencySummary,
            allTags: allTags,
            tagSummaries: tagSummaries,
            suggestedRelatedTags: filterPresentation.suggestedRelatedTags(
                suggestionAnchor: relatedStatsTagSuggestionAnchor
            ),
            taskCountForSelectedTypeFilter: taskCountForSelectedTypeFilter,
            selectedTags: selectedStatsTags,
            includeTagMatchMode: statsStore?.includeTagMatchMode ?? .all,
            onSelectTags: { tags in
                relatedStatsTagSuggestionAnchor = tags.sorted().last
                statsStore?.send(.selectedTagsChanged(tags))
            },
            onIncludeTagMatchModeChange: { mode in
                statsStore?.send(.includeTagMatchModeChanged(mode))
            },
            onSelectSuggestedTag: { tag in
                guard let mutation = filterPresentation.addedIncludedTag(tag) else { return }
                statsStore?.send(.selectedTagsChanged(mutation.selectedTags))
            },
            selectedExcludedTags: selectedStatsExcludedTags,
            excludeTagMatchMode: statsStore?.excludeTagMatchMode ?? .any,
            onExcludeTagMatchModeChange: { mode in
                statsStore?.send(.excludeTagMatchModeChanged(mode))
            },
            availableExcludeTags: availableExcludeTags,
            excludedTagSummary: statsExcludedTagSummary,
            tagSelectionSummary: filterPresentation.tagSelectionSummary(tagCount: tagSummaries.count),
            tagCount: { tag in
                guard let normalizedTag = RoutineTag.normalized(tag) else { return 0 }
                return tagCountsByNormalizedName[normalizedTag] ?? 0
            },
            onToggleExcludedTag: { tag in
                let mutation = filterPresentation.toggledExcludedTag(tag)
                statsStore?.send(.selectedTagsChanged(mutation.selectedTags))
                statsStore?.send(.excludedTagsChanged(mutation.excludedTags))
            }
        )
    }

    private var statsFilterPresentation: StatsFilterPresentation {
        StatsFilterPresentation(
            taskTypeFilter: statsStore?.taskTypeFilter ?? .all,
            advancedQuery: statsStore?.advancedQuery ?? "",
            selectedTags: selectedStatsTags,
            includeTagMatchMode: statsStore?.includeTagMatchMode ?? .all,
            excludedTags: selectedStatsExcludedTags,
            excludeTagMatchMode: statsStore?.excludeTagMatchMode ?? .any,
            selectedImportanceUrgencyFilter: statsStore?.selectedImportanceUrgencyFilter,
            availableTags: statsAllTags,
            relatedTagRules: store.relatedTagRules,
            tagColors: store.tagColors
        )
    }

    private var statsAllTags: [String] {
        if let statsStore {
            return statsStore.availableTags
        }

        var seen = Set<String>()
        var result: [String] = []
        for task in store.routineTasks {
            for tag in task.tags where !seen.contains(tag) {
                seen.insert(tag)
                result.append(tag)
            }
        }
        return result.sorted()
    }

    private var selectedStatsTag: String? {
        statsStore?.selectedTag
    }

    private var selectedStatsTags: Set<String> {
        statsStore?.effectiveSelectedTags ?? []
    }

    private var selectedStatsExcludedTags: Set<String> {
        statsStore?.excludedTags ?? []
    }

    private var statsExcludedTagSummary: String {
        statsFilterPresentation.excludedTagSummary
    }

    private var availableStatsDashboardScopes: [StatsDashboardScope] {
        let reportableItems = availableStatsDashboardItems
        return StatsDashboardScope.allCases.filter { scope in
            guard isStatsDashboardScopeFeatureEnabled(scope) else { return false }
            return scope == .all || reportableItems.contains { $0.isIncluded(in: scope) }
        }
    }

    private var availableStatsDashboardItems: [StatsMacDashboardItem] {
        let selectedRange = statsStore?.selectedRange ?? .week
        let metrics = statsStore?.metrics ?? StatsFeatureMetrics()
        let isGitFeaturesEnabled = statsStore?.isGitFeaturesEnabled ?? settingsStore.appearance.isGitFeaturesEnabled

        return StatsMacDashboardItem.allCases.filter { item in
            (item != .awayTime || isAwayEnabled)
                && (item != .sleepTime || isAwayEnabled)
                && (item != .sleepSessions || isAwayEnabled)
                && item.isAvailable(
                    selectedRange: selectedRange,
                    isGitFeaturesEnabled: isGitFeaturesEnabled,
                    isGoalsTabEnabled: isGoalsTabEnabled,
                    areMacEventEmotionActionsEnabled: areMacEventEmotionActionsEnabled,
                    isStatsWinsEnabled: isStatsWinsEnabled,
                    isStatsAchievementsEnabled: isStatsAchievementsEnabled
                )
                && item.isReportable(metrics: metrics)
        }
    }

    private func isStatsDashboardScopeFeatureEnabled(_ scope: StatsDashboardScope) -> Bool {
        switch scope {
        case .all, .focus:
            return true
        case .sleep:
            return isAwayEnabled && isStatsSleepTabEnabled
        case .wins:
            return isStatsWinsEnabled
        case .achievements:
            return isStatsAchievementsEnabled
        }
    }

    private var resolvedStatsDashboardScope: StatsDashboardScope {
        if !availableStatsDashboardScopes.contains(selectedStatsDashboardScope) {
            return .all
        }
        return selectedStatsDashboardScope
    }

    private var statsImportanceUrgencySummary: String {
        guard let filter = ImportanceUrgencyFilterCell.normalized(statsStore?.selectedImportanceUrgencyFilter) else {
            return "Showing stats across all importance and urgency levels."
        }
        return "Showing stats for tasks with at least \(filter.importance.title.lowercased()) importance and \(filter.urgency.title.lowercased()) urgency."
    }
}
