import ComposableArchitecture
import Foundation

@Reducer
struct TimelineFeature {
    struct TimelineSection: Equatable, Identifiable {
        let date: Date
        var entries: [TimelineEntry]

        var id: Date { date }
    }

    @ObservableState
    struct State: Equatable {
        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var selectedRange: TimelineRange = .all
        var filterType: TimelineFilterType = .all
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var isFilterSheetPresented: Bool = false
        var availableTags: [String] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var groupedEntries: [TimelineSection] = []

        var hasActiveFilters: Bool {
            selectedRange != .all
                || filterType != .all
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
        case setData(tasks: [RoutineTask], logs: [RoutineLog])
        case selectedRangeChanged(TimelineRange)
        case filterTypeChanged(TimelineFilterType)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case setFilterSheet(Bool)
        case clearFilters
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs):
                state.tasks = tasks
                state.logs = logs
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                refreshDerivedState(&state)
                return .none

            case let .selectedRangeChanged(range):
                state.selectedRange = range
                refreshDerivedState(&state)
                return .none

            case let .filterTypeChanged(filterType):
                state.filterType = filterType
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

            case let .excludedTagsChanged(tags):
                state.excludedTags = tags
                refreshDerivedState(&state)
                return .none

            case let .excludeTagMatchModeChanged(mode):
                state.excludeTagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = filter
                refreshDerivedState(&state)
                return .none

            case let .setFilterSheet(isPresented):
                state.isFilterSheetPresented = isPresented
                return .none

            case .clearFilters:
                state.selectedRange = .all
                state.filterType = .all
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedImportanceUrgencyFilter = nil
                refreshDerivedState(&state)
                return .none
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        let baseEntries = TimelineLogic.filteredEntries(
            logs: state.logs,
            tasks: state.tasks,
            range: state.selectedRange,
            filterType: state.filterType,
            now: now,
            calendar: calendar
        )
        let importanceUrgencyFilteredEntries = baseEntries.filter { entry in
            HomeDisplayFilterSupport.matchesImportanceUrgencyFilter(
                state.selectedImportanceUrgencyFilter,
                importance: entry.importance,
                urgency: entry.urgency
            )
        }
        state.availableTags = TimelineLogic.availableTags(from: importanceUrgencyFilteredEntries)
        state.setSelectedTags(state.effectiveSelectedTags.filter { RoutineTag.contains($0, in: state.availableTags) })
        let availableExcludeTags = state.availableTags.filter { tag in
            !state.effectiveSelectedTags.contains { RoutineTag.contains($0, in: [tag]) }
        }
        state.excludedTags = state.excludedTags.filter { RoutineTag.contains($0, in: availableExcludeTags) }

        let entries = importanceUrgencyFilteredEntries.filter { entry in
            HomeDisplayFilterSupport.matchesSelectedTags(
                state.effectiveSelectedTags,
                mode: state.includeTagMatchMode,
                in: entry.tags
            )
                && HomeDisplayFilterSupport.matchesExcludedTags(
                    state.excludedTags,
                    mode: state.excludeTagMatchMode,
                    in: entry.tags
                )
        }
        state.groupedEntries = TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
            .map { TimelineSection(date: $0.date, entries: $0.entries) }
    }
}
