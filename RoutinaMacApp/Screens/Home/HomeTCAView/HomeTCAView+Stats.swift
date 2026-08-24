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
        let availableExcludeTags = statsStore?.availableExcludeTags
            ?? filterPresentation.availableExcludeTags(from: statsTasks)
        let tagCountsByNormalizedName = Dictionary(
            uniqueKeysWithValues: tagSummaries.compactMap { summary in
                RoutineTag.normalized(summary.name).map { ($0, summary.linkedRoutineCount) }
            }
        )
        let tagColorsByNormalizedName: [String: Color] = Dictionary(
            uniqueKeysWithValues: tagSummaries.compactMap { summary in
                guard
                    let normalizedName = RoutineTag.normalized(summary.name),
                    let displayColor = summary.displayColor
                else {
                    return nil
                }
                return (normalizedName, displayColor)
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
            allTags: allTags,
            suggestedRelatedTags: filterPresentation.suggestedRelatedTags(
                suggestionAnchor: relatedStatsTagSuggestionAnchor
            ),
            availableExcludeTags: availableExcludeTags,
            selectedTags: selectedStatsTags,
            includeTagMatchMode: statsStore?.includeTagMatchMode ?? .all,
            selectedExcludedTags: selectedStatsExcludedTags,
            excludeTagMatchMode: statsStore?.excludeTagMatchMode ?? .any,
            tagCount: { tag in
                guard let normalizedTag = RoutineTag.normalized(tag) else { return 0 }
                return tagCountsByNormalizedName[normalizedTag] ?? 0
            },
            tagColor: { tag in
                guard let normalizedTag = RoutineTag.normalized(tag) else { return nil }
                return tagColorsByNormalizedName[normalizedTag]
            },
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
            onExcludeTagMatchModeChange: { mode in
                statsStore?.send(.excludeTagMatchModeChanged(mode))
            },
            onToggleExcludedTag: { tag in
                let mutation = filterPresentation.toggledExcludedTag(tag)
                statsStore?.send(.selectedTagsChanged(mutation.selectedTags))
                statsStore?.send(.excludedTagsChanged(mutation.excludedTags))
            },
            availableFlags: statsStore?.availableFlags ?? [],
            selectedFlags: statsStore?.selectedFlags ?? [],
            includeFlagMatchMode: statsStore?.includeFlagMatchMode ?? .all,
            excludedFlags: statsStore?.excludedFlags ?? [],
            excludeFlagMatchMode: statsStore?.excludeFlagMatchMode ?? .any,
            onIncludeFlagMatchModeChange: { mode in
                statsStore?.send(.includeFlagMatchModeChanged(mode))
            },
            onExcludeFlagMatchModeChange: { mode in
                statsStore?.send(.excludeFlagMatchModeChanged(mode))
            },
            onToggleIncludedFlag: { flag in
                guard let statsStore else { return }
                let mutation = StatsFlagFilterMutationSupport.toggledIncluded(
                    flag,
                    selectedFlags: statsStore.selectedFlags,
                    excludedFlags: statsStore.excludedFlags
                )
                statsStore.send(.selectedFlagsChanged(mutation.selectedFlags))
                statsStore.send(.excludedFlagsChanged(mutation.excludedFlags))
            },
            onToggleExcludedFlag: { flag in
                guard let statsStore else { return }
                let mutation = StatsFlagFilterMutationSupport.toggledExcluded(
                    flag,
                    selectedFlags: statsStore.selectedFlags,
                    excludedFlags: statsStore.excludedFlags
                )
                statsStore.send(.selectedFlagsChanged(mutation.selectedFlags))
                statsStore.send(.excludedFlagsChanged(mutation.excludedFlags))
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
            selectedFlags: statsStore?.selectedFlags ?? [],
            includeFlagMatchMode: statsStore?.includeFlagMatchMode ?? .all,
            excludedFlags: statsStore?.excludedFlags ?? [],
            excludeFlagMatchMode: statsStore?.excludeFlagMatchMode ?? .any,
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

}
