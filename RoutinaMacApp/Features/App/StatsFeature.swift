import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct StatsFeature {
    typealias Metrics = StatsFeatureMetrics

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var focusSessions: [FocusSession] = []
        var sprintFocusSessions: [SprintFocusSessionRecord] = []
        var focusSessionEvents: [FocusSessionActionEvent] = []
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
        var createdChartTaskTypeFilter: StatsTaskTypeFilter = .all
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedFlags: Set<String> = []
        var includeFlagMatchMode: RoutineTagMatchMode = .all
        var excludedFlags: Set<String> = []
        var excludeFlagMatchMode: RoutineTagMatchMode = .any
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
        var advancedQuery: String = ""
        var availableTags: [String] = []
        var tagSummaries: [RoutineTagSummary] = []
        var availableExcludeTags: [String] = []
        var availableFlags: [String] = []
        var availableExcludeFlags: [String] = []
        var tagColors: [String: String] = [:]
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var taskCountForSelectedTypeFilter: Int = 0
        var filteredTaskCount: Int = 0
        var filteredTaskIDs: Set<UUID> = []
        var unassignedFocusSessions: [FocusSession] = []
        var assignableFocusTasks: [RoutineTask] = []
        var activeFocusSprints: [BoardSprintRecord] = []
        var metrics = Metrics()
        var achievementSnapshot = StatsAchievementPresentationSnapshot()
        var gitHubConnection = GitHubConnectionStatus.disconnected
        var gitHubStats: GitHubStatsSnapshot?
        var isGitHubStatsLoading: Bool = false
        var gitHubStatsErrorMessage: String?
        var isGitFeaturesEnabled: Bool = false
        var hasLoadedDataSnapshot = false

        var hasActiveFilters: Bool {
            selectedRange != .week
                || taskTypeFilter != .all
                || !advancedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !effectiveSelectedTags.isEmpty
                || !excludedTags.isEmpty
                || !selectedFlags.isEmpty
                || !excludedFlags.isEmpty
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
            selectedTag = tags.min()
        }
    }

    enum Action: Equatable {
        case setData(
            tasks: [RoutineTask],
            logs: [RoutineLog],
            focusSessions: [FocusSession],
            sprintFocusSessions: [SprintFocusSessionRecord] = [],
            focusSessionEvents: [FocusSessionActionEvent] = [],
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
        case dataRefreshRequested
        case dataRefreshDebounceCompleted
        case activeFocusRefreshTimerTick
        case dataRefreshFailed
        case onAppear
        case selectedRangeChanged(DoneChartRange)
        case taskTypeFilterChanged(StatsTaskTypeFilter)
        case createdChartTaskTypeFilterChanged(StatsTaskTypeFilter)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case advancedQueryChanged(String)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedFlagsChanged(Set<String>)
        case includeFlagMatchModeChanged(RoutineTagMatchMode)
        case excludedFlagsChanged(Set<String>)
        case excludeFlagMatchModeChanged(RoutineTagMatchMode)
        case gitHubStatsRefreshRequested
        case gitHubStatsLoaded(GitHubStatsSnapshot)
        case gitHubStatsFailed(String)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var continuousClock
    @Dependency(\.date.now) var now
    @Dependency(\.gitHubStatsClient) var gitHubStatsClient
    @Dependency(\.gitLabStatsClient) var gitLabStatsClient
    @Dependency(\.appSettingsClient) var appSettingsClient
    @Dependency(\.modelContext) var modelContext

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(
                tasks, logs, focusSessions, sprintFocusSessions, focusSessionEvents,
                boardSprints, sleepSessions, awaySessions, emotionLogs, notes,
                events, noteAttachmentNoteIDs, goals, places, placeCheckInSessions):
                state.hasLoadedDataSnapshot = true
                state.tasks = tasks
                state.logs = logs
                state.focusSessions = focusSessions
                state.sprintFocusSessions = sprintFocusSessions
                state.focusSessionEvents = focusSessionEvents
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
                state.unassignedFocusSessions =
                    focusSessions
                    .filter { $0.isUnassigned && $0.state == .completed }
                    .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                state.assignableFocusTasks =
                    tasks
                    .filter { task in
                        !task.isArchived(referenceDate: now, calendar: calendar)
                            && !task.isCompletedOneOff
                            && !task.isCanceledOneOff
                    }
                    .sorted { lhs, rhs in
                        let lhsTitle = RoutineTask.trimmedName(lhs.name) ?? "Untitled task"
                        let rhsTitle = RoutineTask.trimmedName(rhs.name) ?? "Untitled task"
                        return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
                    }
                state.activeFocusSprints =
                    boardSprints
                    .filter { $0.statusRawValue == SprintStatus.active.rawValue }
                    .sorted { lhs, rhs in
                        let lhsTitle = lhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let rhsTitle = rhs.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        return lhsTitle.localizedCaseInsensitiveCompare(rhsTitle) == .orderedAscending
                    }
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                        + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                state.achievementSnapshot = StatsAchievementPresentationSnapshot.build(
                    focusSessions: focusSessions,
                    sleepSessions: sleepSessions,
                    awaySessions: awaySessions,
                    logs: logs,
                    emotionLogs: emotionLogs,
                    notes: notes,
                    noteAttachmentNoteIDs: noteAttachmentNoteIDs,
                    goals: goals,
                    places: places,
                    placeCheckInSessions: placeCheckInSessions,
                    referenceDate: now,
                    calendar: calendar
                )
                refreshDerivedState(&state)
                return .none

            case .dataRefreshRequested:
                return .run { send in
                    try await continuousClock.sleep(for: .seconds(1))
                    await send(.dataRefreshDebounceCompleted)
                }
                .cancellable(id: CancelID.dataRefreshDebounce, cancelInFlight: true)

            case .dataRefreshDebounceCompleted:
                return refreshDataEffect()

            case .activeFocusRefreshTimerTick:
                let hasActiveUnpausedFocus =
                    state.focusSessions.contains {
                        $0.state == .active && !$0.isPaused
                    }
                    || state.sprintFocusSessions.contains {
                        $0.isActive && !$0.isPaused
                    }
                return hasActiveUnpausedFocus ? refreshDataEffect() : .none

            case .dataRefreshFailed:
                return .none

            case .onAppear:
                let activeFocusTimer = activeFocusRefreshTimerEffect()
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                        + RoutineTagRelations.learnedRules(from: state.tasks.map(\.tags))
                )
                state.tagColors = appSettingsClient.tagColors()
                state.isGitFeaturesEnabled = appSettingsClient.gitFeaturesEnabled()
                guard !state.hasLoadedDataSnapshot else {
                    return activeFocusTimer
                }
                guard state.isGitFeaturesEnabled else {
                    state.gitHubConnection = .disconnected
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                    return .merge(refreshDataEffect(), activeFocusTimer)
                }
                state.gitHubConnection = gitHubStatsClient.loadConnectionStatus()
                if !state.gitHubConnection.isConnected {
                    state.isGitHubStatsLoading = false
                    state.gitHubStats = nil
                    state.gitHubStatsErrorMessage = nil
                }
                return .merge(
                    refreshDataEffect(),
                    refreshGitHubStatsEffect(state: &state),
                    activeFocusTimer
                )

            case let .selectedRangeChanged(range):
                state.selectedRange = range
                refreshDerivedState(&state)
                guard state.isGitFeaturesEnabled, state.gitHubConnection.isConnected else {
                    return .none
                }
                return refreshGitHubStatsEffect(state: &state, skipGitLab: true)

            case let .taskTypeFilterChanged(filter):
                state.taskTypeFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .createdChartTaskTypeFilterChanged(filter):
                state.createdChartTaskTypeFilter = filter
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

            case let .selectedFlagsChanged(flags):
                state.selectedFlags = flags
                refreshDerivedState(&state)
                return .none

            case let .includeFlagMatchModeChanged(mode):
                state.includeFlagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .excludedFlagsChanged(flags):
                state.excludedFlags = flags
                refreshDerivedState(&state)
                return .none

            case let .excludeFlagMatchModeChanged(mode):
                state.excludeFlagMatchMode = mode
                refreshDerivedState(&state)
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

            case .clearFilters:
                state.selectedRange = .week
                state.taskTypeFilter = .all
                state.createdChartTaskTypeFilter = .all
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedFlags = []
                state.includeFlagMatchMode = .all
                state.excludedFlags = []
                state.excludeFlagMatchMode = .any
                state.selectedImportanceUrgencyFilter = nil
                state.advancedQuery = ""
                refreshDerivedState(&state)
                return .none
            }
        }
    }

    enum CancelID {
        case dataRefreshDebounce
        case activeFocusRefreshTimer
    }

}

extension StatsFeature.State: AppStatsFeatureTemporaryViewState {}
