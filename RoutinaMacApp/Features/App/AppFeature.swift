import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var hasRestoredTemporaryViewState = false
        var isMacStatsSurfaceActive = false
        var pendingDeepLinkedTaskID: UUID?
        var pendingDeepLinkedSprintID: UUID?
        var home = HomeFeature.State()
        var goals = GoalsFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
        var backlog = BacklogFeature.State()
        var taskRanking = TaskRankingFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case goals(GoalsFeature.Action)
        case timeline(TimelineFeature.Action)
        case stats(StatsFeature.Action)
        case settings(SettingsFeature.Action)
        case backlog(BacklogFeature.Action)
        case taskRanking(TaskRankingFeature.Action)
        case onAppear
        case cloudSettingsChanged
        case openDeepLink(RoutinaDeepLink)
    }

    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.goals, action: \.goals) {
            GoalsFeature()
        }
        Scope(state: \.timeline, action: \.timeline) {
            TimelineFeature()
        }
        Scope(state: \.stats, action: \.stats) {
            StatsFeature()
        }
        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }
        Scope(state: \.backlog, action: \.backlog) {
            BacklogFeature()
        }
        Scope(state: \.taskRanking, action: \.taskRanking) {
            TaskRankingFeature()
        }
        Reduce { state, action in
            if let interaction = performanceInteraction(for: action) {
                RoutinaPerformanceProfiler.shared.recordInteraction(interaction)
            }

            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                persistTemporaryViewState(state)
                return .none
            case let .openDeepLink(deepLink):
                return handleDeepLink(deepLink, state: &state)
            case let .home(.tasksLoadedSuccessfully(tasks, _, _, _, _)):
                guard let taskID = state.pendingDeepLinkedTaskID,
                    tasks.contains(where: { $0.id == taskID })
                else {
                    return .none
                }
                state.pendingDeepLinkedTaskID = nil
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.openTaskDeepLink(taskID)))
            case let .home(.sprintBoardLoaded(sprintBoardData)):
                return openPendingSprintDeepLinkIfPossible(sprintBoardData, state: &state)
            case let .home(.sprintBoardLoadedFromStorage(sprintBoardData, _)):
                return openPendingSprintDeepLinkIfPossible(sprintBoardData, state: &state)
            case let .home(.macSidebarModeChanged(mode)):
                let isEnteringStats = mode == .stats && !state.isMacStatsSurfaceActive
                state.isMacStatsSurfaceActive = mode == .stats
                return isEnteringStats ? .send(.stats(.dataRefreshRequested)) : .none
            case .onAppear:
                guard !state.hasRestoredTemporaryViewState else { return .none }
                state.hasRestoredTemporaryViewState = true
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .none
            case .cloudSettingsChanged:
                let tagColors = appSettingsClient.tagColors()
                let relatedTagRules = appSettingsClient.relatedTagRules()
                let flagRules = appSettingsClient.flagRules()
                state.home.tagColors = tagColors
                state.home.flagRules = flagRules
                state.home.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.home.routineTasks.map(\.tags))
                )
                state.timeline.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.timeline.tasks.map(\.tags))
                )
                state.goals.tagColors = tagColors
                state.goals.availableTagSummaries = RoutineTagColors.applying(
                    tagColors,
                    to: state.goals.availableTagSummaries
                )
                state.goals.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.goals.goals.map(\.tags))
                )
                state.stats.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.stats.tasks.map(\.tags))
                )
                SettingsTagEditor.loadedTagColors(tagColors, state: &state.settings.tags)
                SettingsTagEditor.loadedRelatedTagRules(relatedTagRules, state: &state.settings.tags)
                SettingsFlagEditor.loadedRules(flagRules, state: &state.settings.flags)
                SettingsFlagEditor.loadedDefinedFlags(
                    appSettingsClient.definedFlags(),
                    state: &state.settings.flags
                )
                return .send(.timeline(.flagRulesChanged(flagRules)))
            case .settings(.resetTemporaryViewStateTapped):
                let timelineTasks = state.timeline.tasks
                let timelineLogs = state.timeline.logs
                let timelineEvents = state.timeline.events
                let timelineNotes = state.timeline.notes
                let timelineFocusSessions = state.timeline.focusSessions
                let timelineSprintFocusSessions = state.timeline.sprintFocusSessions
                let timelineFocusSessionEvents = state.timeline.focusSessionEvents
                let timelineBoardSprints = state.timeline.boardSprints
                let timelineAwaySessions = state.timeline.awaySessions
                let timelineFileAttachmentTaskIDs = state.timeline.fileAttachmentTaskIDs
                let timelineNoteAttachmentNoteIDs = state.timeline.noteAttachmentNoteIDs
                let statsTasks = state.stats.tasks
                let statsLogs = state.stats.logs
                let statsFocusSessions = state.stats.focusSessions
                let statsSprintFocusSessions = state.stats.sprintFocusSessions
                let statsFocusSessionEvents = state.stats.focusSessionEvents
                let statsBoardSprints = state.stats.boardSprints
                let statsSleepSessions = state.stats.sleepSessions
                let statsAwaySessions = state.stats.awaySessions
                let statsEmotionLogs = state.stats.emotionLogs
                let statsNotes = state.stats.notes
                let statsEvents = state.stats.events
                let statsNoteAttachmentNoteIDs = state.stats.noteAttachmentNoteIDs
                let statsGoals = state.stats.goals
                let statsPlaces = state.stats.places
                let statsPlaceCheckInSessions = state.stats.placeCheckInSessions
                resetTemporaryViewState(&state)
                persistTemporaryViewState(state)
                return .merge(
                    .send(
                        .timeline(
                            .setData(
                                tasks: timelineTasks,
                                logs: timelineLogs,
                                events: timelineEvents,
                                notes: timelineNotes,
                                focusSessions: timelineFocusSessions,
                                sprintFocusSessions: timelineSprintFocusSessions,
                                focusSessionEvents: timelineFocusSessionEvents,
                                boardSprints: timelineBoardSprints,
                                awaySessions: timelineAwaySessions,
                                fileAttachmentTaskIDs: timelineFileAttachmentTaskIDs,
                                noteAttachmentNoteIDs: timelineNoteAttachmentNoteIDs
                            ))),
                    .send(
                        .stats(
                            .setData(
                                tasks: statsTasks,
                                logs: statsLogs,
                                focusSessions: statsFocusSessions,
                                sprintFocusSessions: statsSprintFocusSessions,
                                focusSessionEvents: statsFocusSessionEvents,
                                boardSprints: statsBoardSprints,
                                sleepSessions: statsSleepSessions,
                                awaySessions: statsAwaySessions,
                                emotionLogs: statsEmotionLogs,
                                notes: statsNotes,
                                events: statsEvents,
                                noteAttachmentNoteIDs: statsNoteAttachmentNoteIDs,
                                goals: statsGoals,
                                places: statsPlaces,
                                placeCheckInSessions: statsPlaceCheckInSessions
                            )))
                )
            case .timeline(.selectedRangeChanged),
                .timeline(.filterTypeChanged),
                .timeline(.selectedTagChanged),
                .timeline(.selectedTagsChanged),
                .timeline(.includeTagMatchModeChanged),
                .timeline(.excludedTagsChanged),
                .timeline(.excludeTagMatchModeChanged),
                .timeline(.selectedFlagsChanged),
                .timeline(.includeFlagMatchModeChanged),
                .timeline(.selectedImportanceUrgencyFilterChanged),
                .timeline(.mediaFilterChanged),
                .timeline(.clearFilters),
                .stats(.selectedRangeChanged),
                .stats(.taskTypeFilterChanged),
                .stats(.selectedTagChanged),
                .stats(.selectedTagsChanged),
                .stats(.includeTagMatchModeChanged),
                .stats(.advancedQueryChanged),
                .stats(.selectedImportanceUrgencyFilterChanged),
                .stats(.excludedTagsChanged),
                .stats(.excludeTagMatchModeChanged),
                .stats(.selectedFlagsChanged),
                .stats(.includeFlagMatchModeChanged),
                .stats(.excludedFlagsChanged),
                .stats(.excludeFlagMatchModeChanged),
                .stats(.clearFilters):
                persistTemporaryViewState(state)
                return .none
            case .settings(.tagColorChanged):
                state.home.tagColors = appSettingsClient.tagColors()
                return .none
            case .settings(.addFlagRuleTapped),
                .settings(.removeFlagRuleTapped),
                .settings(.removeFlagTapped):
                let flagRules = RoutineFlagRules.sanitized(appSettingsClient.flagRules())
                state.home.flagRules = flagRules
                return .send(.timeline(.flagRulesChanged(flagRules)))
            default:
                return .none
            }
        }
    }

    private func applyTemporaryViewState(_ persistedState: TemporaryViewState?, to state: inout State) {
        AppFeatureTemporaryViewStateSupport.apply(persistedState, to: &state)
    }

    private func resetTemporaryViewState(_ state: inout State) {
        AppFeatureTemporaryViewStateSupport.reset(&state, homeTaskListMode: .all)
    }

    private func persistTemporaryViewState(_ state: State) {
        appSettingsClient.setTemporaryViewState(
            AppFeatureTemporaryViewStateSupport.makeTemporaryViewState(
                from: state,
                preserving: appSettingsClient.temporaryViewState()
            )
        )
    }

    private func handleDeepLink(_ deepLink: RoutinaDeepLink, state: inout State) -> Effect<Action> {
        if case .goal = deepLink,
            !appSettingsClient.goalsEnabled()
        {
            return .none
        }
        if case .event = deepLink,
            !appSettingsClient.eventEmotionActionsEnabled()
        {
            return .none
        }
        state.hasRestoredTemporaryViewState = true

        switch deepLink {
        case let .task(taskID):
            state.selectedTab = .home
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)

            guard state.home.routineTasks.contains(where: { $0.id == taskID }) else {
                state.pendingDeepLinkedTaskID = taskID
                return .send(.home(.onAppear))
            }

            state.pendingDeepLinkedTaskID = nil
            return .send(.home(.openTaskDeepLink(taskID)))
        case let .goal(goalID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .concatenate(
                .send(.home(.macSidebarModeChanged(.goals))),
                .send(.goals(.openGoalDeepLink(goalID)))
            )
        case let .note(noteID):
            guard appSettingsClient.notesEnabled() else { return .none }
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .send(.home(.openNoteDeepLink(noteID)))
        case let .event(eventID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .send(.home(.openEventDeepLink(eventID)))
        case let .sleep(sleepID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            state.pendingDeepLinkedSprintID = nil
            persistTemporaryViewState(state)
            return .send(.home(.openSleepDeepLink(sleepID)))
        case let .sprint(sprintID):
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)

            guard state.home.sprintBoardData.sprints.contains(where: { $0.id == sprintID }) else {
                state.pendingDeepLinkedSprintID = sprintID
                return .send(.home(.onAppear))
            }

            state.pendingDeepLinkedSprintID = nil
            return .send(.home(.openSprintDeepLink(sprintID)))
        }
    }

    private func openPendingSprintDeepLinkIfPossible(
        _ sprintBoardData: SprintBoardData,
        state: inout State
    ) -> Effect<Action> {
        guard let sprintID = state.pendingDeepLinkedSprintID,
            sprintBoardData.sprints.contains(where: { $0.id == sprintID })
        else {
            return .none
        }

        state.pendingDeepLinkedSprintID = nil
        state.selectedTab = .home
        persistTemporaryViewState(state)
        return .send(.home(.openSprintDeepLink(sprintID)))
    }
}

extension AppFeature.State: AppFeatureTemporaryViewState {}
