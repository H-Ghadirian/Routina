import ComposableArchitecture
import Foundation
import SwiftData

extension StatsFeature {
    func activeFocusRefreshTimerEffect() -> Effect<Action> {
        .run { send in
            while !Task.isCancelled {
                try await continuousClock.sleep(for: .seconds(30))
                await send(.activeFocusRefreshTimerTick)
            }
        }
        .cancellable(id: CancelID.activeFocusRefreshTimer, cancelInFlight: true)
    }

    func refreshDataEffect() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let context = modelContext()
                let notesEnabled = appSettingsClient.notesEnabled()
                let placesEnabled = appSettingsClient.placesEnabled()
                let awayEnabled = appSettingsClient.awayEnabled()

                let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
                let logs = try context.fetch(FetchDescriptor<RoutineLog>())
                let focusSessions = try context.fetch(FetchDescriptor<FocusSession>())
                let sprintFocusSessions = try context.fetch(FetchDescriptor<SprintFocusSessionRecord>())
                let focusSessionEvents = try FocusSessionActionEvent.fetch(from: context)
                let boardSprints = try context.fetch(FetchDescriptor<BoardSprintRecord>())
                let sleepSessions = try context.fetch(FetchDescriptor<SleepSession>())
                let awaySessions = try context.fetch(FetchDescriptor<AwaySession>())
                let emotionLogs = try context.fetch(FetchDescriptor<EmotionLog>())
                let notes = try context.fetch(FetchDescriptor<RoutineNote>())
                let events = try context.fetch(FetchDescriptor<RoutineEvent>())
                let noteAttachments = try context.fetch(FetchDescriptor<RoutineNoteAttachment>())
                let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
                let places = try context.fetch(FetchDescriptor<RoutinePlace>())
                let placeCheckInSessions = try context.fetch(FetchDescriptor<PlaceCheckInSession>())

                send(
                    .setData(
                        tasks: tasks,
                        logs: logs,
                        focusSessions: focusSessions,
                        sprintFocusSessions: sprintFocusSessions,
                        focusSessionEvents: focusSessionEvents,
                        boardSprints: boardSprints,
                        sleepSessions: awayEnabled ? sleepSessions : [],
                        awaySessions: awayEnabled ? awaySessions : [],
                        emotionLogs: emotionLogs,
                        notes: notesEnabled ? notes : [],
                        events: events,
                        noteAttachmentNoteIDs: notesEnabled ? Set(noteAttachments.map(\.noteID)) : [],
                        goals: goals,
                        places: placesEnabled ? places : [],
                        placeCheckInSessions: placesEnabled ? placeCheckInSessions : []
                    ))
            } catch {
                send(.dataRefreshFailed)
            }
        }
    }

    func refreshGitHubStatsEffect(
        state: inout State,
        skipGitLab: Bool = false
    ) -> Effect<Action> {
        let isGitHubConnected = state.gitHubConnection.isConnected
        guard state.isGitFeaturesEnabled else {
            state.isGitHubStatsLoading = false
            state.gitHubStatsErrorMessage = nil
            return .none
        }
        if isGitHubConnected {
            state.isGitHubStatsLoading = true
            state.gitHubStatsErrorMessage = nil
        }
        let range = state.selectedRange
        let isProfile = state.gitHubConnection.scope == .profile

        return .run { send in
            if isGitHubConnected {
                do {
                    let stats = try await self.gitHubStatsClient.fetchStats(range)
                    await send(.gitHubStatsLoaded(stats))
                } catch {
                    await send(.gitHubStatsFailed(error.localizedDescription))
                }
            }
            if isGitHubConnected, isProfile {
                do {
                    let data = try await self.gitHubStatsClient.fetchContributionYear()
                    GitHubWidgetService.writeAndReload(data)
                } catch {
                    RoutinaLog.error("GitHubWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else {
                RoutinaLog.notice("GitHubWidgetService: skipping widget fetch — scope is not profile")
            }

            if !skipGitLab, self.gitLabStatsClient.loadConnectionStatus().isConnected {
                do {
                    let data = try await self.gitLabStatsClient.fetchContributionYear()
                    GitLabWidgetService.writeAndReload(data)
                } catch {
                    RoutinaLog.error("GitLabWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if !skipGitLab {
                RoutinaLog.notice("GitLabWidgetService: skipping widget fetch — not connected")
            }
        }
    }

    func refreshDerivedState(_ state: inout State) {
        let derivedState = StatsFeatureDerivedStateBuilder.build(
            tasks: state.tasks,
            logs: state.logs,
            focusSessions: state.focusSessions,
            sprintFocusSessions: state.sprintFocusSessions,
            focusSessionEvents: state.focusSessionEvents,
            boardSprints: state.boardSprints,
            sleepSessions: state.sleepSessions,
            awaySessions: state.awaySessions,
            emotionLogs: state.emotionLogs,
            notes: state.notes,
            events: state.events,
            noteAttachmentNoteIDs: state.noteAttachmentNoteIDs,
            goals: state.goals,
            selectedRange: state.selectedRange,
            taskTypeFilter: state.taskTypeFilter,
            createdChartTaskTypeFilter: state.createdChartTaskTypeFilter,
            selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
            advancedQuery: state.advancedQuery,
            selectedTags: state.effectiveSelectedTags,
            includeTagMatchMode: state.includeTagMatchMode,
            excludedTags: state.excludedTags,
            excludeTagMatchMode: state.excludeTagMatchMode,
            selectedFlags: state.selectedFlags,
            includeFlagMatchMode: state.includeFlagMatchMode,
            excludedFlags: state.excludedFlags,
            excludeFlagMatchMode: state.excludeFlagMatchMode,
            tagColors: state.tagColors,
            referenceDate: state.selectedRange.referenceDate(relativeTo: now),
            calendar: calendar
        )
        state.availableTags = derivedState.availableTags
        state.setSelectedTags(derivedState.selectedTags)
        state.excludedTags = derivedState.excludedTags
        state.selectedFlags = derivedState.selectedFlags
        state.excludedFlags = derivedState.excludedFlags
        state.tagSummaries = derivedState.tagSummaries
        state.availableExcludeTags = derivedState.availableExcludeTags
        state.availableFlags = derivedState.availableFlags
        state.availableExcludeFlags = derivedState.availableExcludeFlags
        state.taskCountForSelectedTypeFilter = derivedState.taskCountForSelectedTypeFilter
        state.filteredTaskCount = derivedState.filteredTaskCount
        state.filteredTaskIDs = derivedState.filteredTaskIDs
        state.metrics = derivedState.metrics
    }
}
