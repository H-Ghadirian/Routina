import ComposableArchitecture
import Foundation

@Reducer
struct AppFeature {

    @ObservableState
    struct State: Equatable {
        var selectedTab: Tab = .home
        var hasRestoredTemporaryViewState = false
        var pendingDeepLinkedTaskID: UUID?
        var home = HomeFeature.State()
        var goals = GoalsFeature.State()
        var timeline = TimelineFeature.State()
        var stats = StatsFeature.State()
        var settings = SettingsFeature.State()
    }

    @CasePathable
    enum Action: Equatable {
        case tabSelected(Tab)
        case homeFastFilterSelected(String)
        case home(HomeFeature.Action)
        case goals(GoalsFeature.Action)
        case timeline(TimelineFeature.Action)
        case stats(StatsFeature.Action)
        case settings(SettingsFeature.Action)
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
        Reduce { state, action in
            switch action {
            case .tabSelected(let tab):
                state.selectedTab = tab
                persistTemporaryViewState(state)
                return .none
            case let .homeFastFilterSelected(tag):
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.applyFastTagFilter(tag)))
            case let .openDeepLink(deepLink):
                return handleDeepLink(deepLink, state: &state)
            case let .home(.tasksLoadedSuccessfully(tasks, _, _, _, _)):
                guard let taskID = state.pendingDeepLinkedTaskID,
                      tasks.contains(where: { $0.id == taskID }) else {
                    return .none
                }
                state.pendingDeepLinkedTaskID = nil
                state.selectedTab = .home
                persistTemporaryViewState(state)
                return .send(.home(.setSelectedTask(taskID)))
            case .onAppear:
                guard !state.hasRestoredTemporaryViewState else { return .none }
                state.hasRestoredTemporaryViewState = true
                applyTemporaryViewState(appSettingsClient.temporaryViewState(), to: &state)
                return .none
            case .cloudSettingsChanged:
                let tagColors = appSettingsClient.tagColors()
                let relatedTagRules = appSettingsClient.relatedTagRules()
                state.home.tagColors = tagColors
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
                state.stats.tagColors = tagColors
                state.stats.relatedTagRules = RoutineTagRelations.sanitized(
                    relatedTagRules + RoutineTagRelations.learnedRules(from: state.stats.tasks.map(\.tags))
                )
                SettingsTagEditor.loadedTagColors(tagColors, state: &state.settings.tags)
                SettingsTagEditor.loadedRelatedTagRules(relatedTagRules, state: &state.settings.tags)
                return .none
            case .settings(.resetTemporaryViewStateTapped):
                let timelineTasks = state.timeline.tasks
                let timelineLogs = state.timeline.logs
                let timelineEvents = state.timeline.events
                let timelineNotes = state.timeline.notes
                let timelineFocusSessions = state.timeline.focusSessions
                let timelineSprintFocusSessions = state.timeline.sprintFocusSessions
                let timelineBoardSprints = state.timeline.boardSprints
                let timelineAwaySessions = state.timeline.awaySessions
                let timelineFileAttachmentTaskIDs = state.timeline.fileAttachmentTaskIDs
                let timelineNoteAttachmentNoteIDs = state.timeline.noteAttachmentNoteIDs
                let statsTasks = state.stats.tasks
                let statsLogs = state.stats.logs
                let statsFocusSessions = state.stats.focusSessions
                let statsSprintFocusSessions = state.stats.sprintFocusSessions
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
                    .send(.timeline(.setData(
                        tasks: timelineTasks,
                        logs: timelineLogs,
                        events: timelineEvents,
                        notes: timelineNotes,
                        focusSessions: timelineFocusSessions,
                        sprintFocusSessions: timelineSprintFocusSessions,
                        boardSprints: timelineBoardSprints,
                        awaySessions: timelineAwaySessions,
                        fileAttachmentTaskIDs: timelineFileAttachmentTaskIDs,
                        noteAttachmentNoteIDs: timelineNoteAttachmentNoteIDs
                    ))),
                    .send(.stats(.setData(
                        tasks: statsTasks,
                        logs: statsLogs,
                        focusSessions: statsFocusSessions,
                        sprintFocusSessions: statsSprintFocusSessions,
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
                 .timeline(.selectedImportanceUrgencyFilterChanged),
                 .timeline(.mediaFilterChanged),
                 .timeline(.excludedTagsChanged),
                 .timeline(.excludeTagMatchModeChanged),
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
                 .stats(.clearFilters):
                persistTemporaryViewState(state)
                return .none
            case .settings(.tagColorChanged):
                let tagColors = appSettingsClient.tagColors()
                state.home.tagColors = tagColors
                state.stats.tagColors = tagColors
                return .none
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
        state.stats.isFilterSheetPresented = false
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
        state.hasRestoredTemporaryViewState = true

        switch deepLink {
        case let .task(taskID):
            state.selectedTab = .home
            persistTemporaryViewState(state)

            guard state.home.routineTasks.contains(where: { $0.id == taskID }) else {
                state.pendingDeepLinkedTaskID = taskID
                return .send(.home(.onAppear))
            }

            state.pendingDeepLinkedTaskID = nil
            return .send(.home(.setSelectedTask(taskID)))
        case let .goal(goalID):
            state.selectedTab = .goals
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.goals(.openGoalDeepLink(goalID)))
        case let .note(noteID):
            state.selectedTab = .timeline
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.timeline(.openNoteDeepLink(noteID)))
        case let .event(eventID):
            state.selectedTab = .timeline
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.timeline(.openEventDeepLink(eventID)))
        case .sleep:
            state.selectedTab = .timeline
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .none
        case .sprint:
            state.selectedTab = .home
            state.pendingDeepLinkedTaskID = nil
            persistTemporaryViewState(state)
            return .send(.home(.onAppear))
        }
    }
}

@Reducer
struct StatsFeature {
    typealias Metrics = StatsFeatureMetrics

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var focusSessions: [FocusSession] = []
        var sprintFocusSessions: [SprintFocusSessionRecord] = []
        var boardSprints: [BoardSprintRecord] = []
        var sleepSessions: [SleepSession] = []
        var awaySessions: [AwaySession] = []
        var emotionLogs: [EmotionLog] = []
        var notes: [RoutineNote] = []
        var events: [RoutineEvent] = []
        var noteAttachmentNoteIDs: Set<UUID> = []
        var goals: [RoutineGoal] = []
        var places: [RoutinePlace] = []
        var placeCheckInSessions: [PlaceCheckInSession] = []
        var selectedRange: DoneChartRange = .week
        var taskTypeFilter: StatsTaskTypeFilter = .all
        var isFilterSheetPresented: Bool = false
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var advancedQuery: String = ""
        var availableTags: [String] = []
        var tagColors: [String: String] = [:]
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var filteredTaskCount: Int = 0
        var metrics = Metrics()
        var gitHubConnection = GitHubConnectionStatus.disconnected
        var gitHubStats: GitHubStatsSnapshot?
        var isGitHubStatsLoading: Bool = false
        var gitHubStatsErrorMessage: String?
        var isGitFeaturesEnabled: Bool = false
        var healthAccessState: HealthStatsAccessState = .notRequested
        var healthSummary: HealthStatsSummary?
        var isHealthStatsLoading: Bool = false
        var healthStatsErrorMessage: String?

        var hasActiveFilters: Bool {
            selectedRange != .week
                || taskTypeFilter != .all
                || !advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !effectiveSelectedTags.isEmpty
                || !excludedTags.isEmpty
                || selectedImportanceUrgencyFilter != nil
        }

        var effectiveSelectedTags: Set<String> {
            if !selectedTags.isEmpty { return selectedTags }
            return selectedTag.map { [$0] } ?? []
        }

        mutating func setSelectedTag(_ tag: String?) {
            selectedTag = tag
            selectedTags = tag.map { [$0] } ?? []
        }

        mutating func setSelectedTags(_ tags: Set<String>) {
            selectedTags = tags
            selectedTag = tags.sorted().first
        }
    }

    enum Action: Equatable {
        case setData(
            tasks: [RoutineTask],
            logs: [RoutineLog],
            focusSessions: [FocusSession],
            sprintFocusSessions: [SprintFocusSessionRecord] = [],
            boardSprints: [BoardSprintRecord] = [],
            sleepSessions: [SleepSession] = [],
            awaySessions: [AwaySession] = [],
            emotionLogs: [EmotionLog] = [],
            notes: [RoutineNote] = [],
            events: [RoutineEvent] = [],
            noteAttachmentNoteIDs: Set<UUID> = [],
            goals: [RoutineGoal] = [],
            places: [RoutinePlace] = [],
            placeCheckInSessions: [PlaceCheckInSession] = []
        )
        case onAppear
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case advancedQueryChanged(String)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case setFilterSheet(Bool)
        case gitHubStatsRefreshRequested
        case gitHubStatsLoaded(GitHubStatsSnapshot)
        case gitHubStatsFailed(String)
        case healthStatsAuthorizationRequested
        case healthStatsRefreshRequested
        case healthStatsLoaded(HealthStatsSummary)
        case healthStatsFailed(String)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.gitHubStatsClient) var gitHubStatsClient
    @Dependency(\.gitLabStatsClient) var gitLabStatsClient
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.healthStatsClient) var healthStatsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, awaySessions, emotionLogs, notes, events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions):
                state.tasks = tasks
                state.logs = logs
                state.focusSessions = focusSessions
                state.sprintFocusSessions = sprintFocusSessions
                state.boardSprints = boardSprints
                state.sleepSessions = sleepSessions
                state.awaySessions = awaySessions
                state.emotionLogs = emotionLogs
                state.notes = notes
                state.events = events
                state.noteAttachmentNoteIDs = noteAttachmentNoteIDs
                state.goals = goals
                state.places = places
                state.placeCheckInSessions = placeCheckInSessions
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                refreshDerivedState(&state)
                return .none

            case .onAppear:
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: state.tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                var effects: [Effect<Action>] = []
                configureHealthStatsOnAppear(state: &state, effects: &effects)
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    return effects.isEmpty ? .none : .merge(effects)
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                }
                effects.append(refreshGitHubStatsEffect(state: &state))
                return .merge(effects)

            case let .selectedRangeChanged(range):
                state.selectedRange = range
                refreshDerivedState(&state)
                var effects: [Effect<Action>] = []
                guard state.isGitFeaturesEnabled, state.gitHubConnection.isConnected else {
                    if state.healthAccessState == .ready {
                        effects.append(refreshHealthStatsEffect(state: &state))
                    }
                    return effects.isEmpty ? .none : .merge(effects)
                }
                effects.append(refreshGitHubStatsEffect(state: &state, skipGitLab: true))
                if state.healthAccessState == .ready {
                    effects.append(refreshHealthStatsEffect(state: &state))
                }
                return .merge(effects)

            case let .taskTypeFilterChanged(filter):
                state.taskTypeFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .selectedTagChanged(tag):
                state.setSelectedTag(tag)
                refreshDerivedState(&state)
                return .none

            case let .selectedTagsChanged(tags):
                state.setSelectedTags(tags)
                refreshDerivedState(&state)
                return .none

            case let .includeTagMatchModeChanged(mode):
                state.includeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .advancedQueryChanged(query):
                state.advancedQuery = query
                refreshDerivedState(&state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.normalized(filter)
                refreshDerivedState(&state)
                return .none

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                refreshDerivedState(&state)
                return .none

            case let .excludeTagMatchModeChanged(mode):
                state.excludeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .gitHubStatsRefreshRequested:
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    state.isGitHubStatsLoading = false
                    return .none
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    state.isGitHubStatsLoading = false
                }
                return refreshGitHubStatsEffect(state: &state)

            case let .gitHubStatsLoaded(stats):
                state.isGitHubStatsLoading = false
                state.gitHubStats = stats
                state.gitHubStatsErrorMessage = nil
                return .none

            case let .gitHubStatsFailed(message):
                state.isGitHubStatsLoading = false
                state.gitHubStatsErrorMessage = message
                return .none

            case .healthStatsAuthorizationRequested:
                return requestHealthStatsAuthorizationEffect(state: &state)

            case .healthStatsRefreshRequested:
                return refreshHealthStatsEffect(state: &state)

            case let .healthStatsLoaded(summary):
                state.healthAccessState = .ready
                state.healthSummary = summary
                state.isHealthStatsLoading = false
                state.healthStatsErrorMessage = nil
                return .none

            case let .healthStatsFailed(message):
                state.healthAccessState = state.healthSummary == nil ? .failed : .ready
                state.isHealthStatsLoading = false
                state.healthStatsErrorMessage = message
                return .none

            case .clearFilters:
                state.selectedRange = .week
                state.taskTypeFilter = .all
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedImportanceUrgencyFilter = nil
                state.advancedQuery = ""
                refreshDerivedState(&state)
                guard state.healthAccessState == .ready else { return .none }
                return refreshHealthStatsEffect(state: &state)
            }
        }
    }

    private func configureHealthStatsOnAppear(
        state: inout State,
        effects: inout [Effect<Action>]
    ) {
        guard healthStatsClient.isHealthDataAvailable() else {
            state.healthAccessState = .unavailable
            state.healthSummary = nil
            state.isHealthStatsLoading = false
            state.healthStatsErrorMessage = nil
            return
        }

        guard healthStatsClient.hasRequestedAuthorization() else {
            state.healthAccessState = .notRequested
            state.isHealthStatsLoading = false
            state.healthStatsErrorMessage = nil
            return
        }

        state.healthAccessState = .ready
        effects.append(refreshHealthStatsEffect(state: &state))
    }

    private func requestHealthStatsAuthorizationEffect(state: inout State) -> Effect<Action> {
        guard healthStatsClient.isHealthDataAvailable() else {
            state.healthAccessState = .unavailable
            state.healthSummary = nil
            state.isHealthStatsLoading = false
            state.healthStatsErrorMessage = nil
            return .none
        }

        state.isHealthStatsLoading = true
        state.healthStatsErrorMessage = nil
        let range = state.selectedRange
        let referenceDate = now
        let currentCalendar = calendar

        return .run { send in
            do {
                let didCompleteAuthorization = try await self.healthStatsClient.requestAuthorization()
                self.healthStatsClient.setHasRequestedAuthorization(didCompleteAuthorization)
                guard didCompleteAuthorization else {
                    await send(.healthStatsFailed("Health access was not granted."))
                    return
                }

                let summary = try await self.healthStatsClient.fetchSummary(
                    range,
                    referenceDate,
                    currentCalendar
                )
                await send(.healthStatsLoaded(summary))
            } catch {
                await send(.healthStatsFailed(error.localizedDescription))
            }
        }
    }

    private func refreshHealthStatsEffect(state: inout State) -> Effect<Action> {
        guard healthStatsClient.isHealthDataAvailable() else {
            state.healthAccessState = .unavailable
            state.healthSummary = nil
            state.isHealthStatsLoading = false
            state.healthStatsErrorMessage = nil
            return .none
        }

        guard healthStatsClient.hasRequestedAuthorization() || state.healthAccessState == .ready else {
            state.healthAccessState = .notRequested
            state.isHealthStatsLoading = false
            state.healthStatsErrorMessage = nil
            return .none
        }

        state.healthAccessState = .ready
        state.isHealthStatsLoading = true
        state.healthStatsErrorMessage = nil
        let range = state.selectedRange
        let referenceDate = now
        let currentCalendar = calendar

        return .run { send in
            do {
                let summary = try await self.healthStatsClient.fetchSummary(
                    range,
                    referenceDate,
                    currentCalendar
                )
                await send(.healthStatsLoaded(summary))
            } catch {
                await send(.healthStatsFailed(error.localizedDescription))
            }
        }
    }

    private func refreshGitHubStatsEffect(
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
                    NSLog("GitHubWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if isGitHubConnected {
                NSLog("GitHubWidgetService: skipping widget fetch — scope is not profile")
            }

            if !skipGitLab, self.gitLabStatsClient.loadConnectionStatus().isConnected {
                do {
                    let data = try await self.gitLabStatsClient.fetchContributionYear()
                    GitLabWidgetService.writeAndReload(data)
                } catch {
                    NSLog("GitLabWidgetService: fetchContributionYear failed — \(error.localizedDescription)")
                }
            } else if !skipGitLab {
                NSLog("GitLabWidgetService: skipping widget fetch — not connected")
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        let derivedState = StatsFeatureDerivedStateBuilder.build(
            tasks: state.tasks,
            logs: state.logs,
            focusSessions: state.focusSessions,
            sprintFocusSessions: state.sprintFocusSessions,
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
            selectedImportanceUrgencyFilter: state.selectedImportanceUrgencyFilter,
            advancedQuery: state.advancedQuery,
            selectedTags: state.effectiveSelectedTags,
            includeTagMatchMode: state.includeTagMatchMode,
            excludedTags: state.excludedTags,
            excludeTagMatchMode: state.excludeTagMatchMode,
            tagColors: state.tagColors,
            referenceDate: now,
            calendar: calendar
        )
        state.availableTags = derivedState.availableTags
        state.setSelectedTags(derivedState.selectedTags)
        state.excludedTags = derivedState.excludedTags
        state.filteredTaskCount = derivedState.filteredTaskCount
        state.metrics = derivedState.metrics
    }
}

extension AppFeature.State: AppFeatureTemporaryViewState {}

extension StatsFeature.State: AppStatsFeatureTemporaryViewState {}
