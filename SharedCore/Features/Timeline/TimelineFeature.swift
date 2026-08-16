import ComposableArchitecture
import Foundation
import SwiftData

struct TimelineDataSnapshot {
    var tasks: [RoutineTask] = []
    var logs: [RoutineLog] = []
    var fileAttachments: [RoutineAttachment] = []
    var events: [RoutineEvent] = []
    var emotionLogs: [EmotionLog] = []
    var notes: [RoutineNote] = []
    var noteAttachments: [RoutineNoteAttachment] = []
    var focusSessions: [FocusSession] = []
    var sprintFocusSessions: [SprintFocusSessionRecord] = []
    var boardSprints: [BoardSprintRecord] = []
    var sleepSessions: [SleepSession] = []
    var awaySessions: [AwaySession] = []
    var placeCheckInSessions: [PlaceCheckInSession] = []
    var tasksByID: [UUID: RoutineTask] = [:]
    var eventsByID: [UUID: RoutineEvent] = [:]
    var emotionLogsByID: [UUID: EmotionLog] = [:]
    var notesByID: [UUID: RoutineNote] = [:]
    var noteAttachmentsByNoteID: [UUID: [RoutineNoteAttachment]] = [:]
    var awaySessionsByID: [UUID: AwaySession] = [:]
    var placeCheckInSessionsByID: [UUID: PlaceCheckInSession] = [:]

    @MainActor
    static func fetch(from context: ModelContext) throws -> Self {
        var snapshot = Self(
            tasks: try context.fetch(FetchDescriptor<RoutineTask>()),
            logs: try context.fetch(FetchDescriptor<RoutineLog>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )),
            fileAttachments: try context.fetch(FetchDescriptor<RoutineAttachment>()),
            events: try context.fetch(FetchDescriptor<RoutineEvent>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            emotionLogs: try context.fetch(FetchDescriptor<EmotionLog>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )),
            notes: try context.fetch(FetchDescriptor<RoutineNote>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )),
            noteAttachments: try context.fetch(FetchDescriptor<RoutineNoteAttachment>()),
            focusSessions: try context.fetch(FetchDescriptor<FocusSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            sprintFocusSessions: try context.fetch(FetchDescriptor<SprintFocusSessionRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            boardSprints: try context.fetch(FetchDescriptor<BoardSprintRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )),
            sleepSessions: try context.fetch(FetchDescriptor<SleepSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            awaySessions: try context.fetch(FetchDescriptor<AwaySession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )),
            placeCheckInSessions: try context.fetch(FetchDescriptor<PlaceCheckInSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            ))
        )
        snapshot.rebuildLookups()
        return snapshot
    }

    private mutating func rebuildLookups() {
        tasksByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        eventsByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        emotionLogsByID = Dictionary(uniqueKeysWithValues: emotionLogs.map { ($0.id, $0) })
        notesByID = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
        awaySessionsByID = Dictionary(uniqueKeysWithValues: awaySessions.map { ($0.id, $0) })
        placeCheckInSessionsByID = Dictionary(
            uniqueKeysWithValues: placeCheckInSessions.map { ($0.id, $0) }
        )
        noteAttachmentsByNoteID = Dictionary(grouping: noteAttachments, by: \.noteID)
            .mapValues { attachments in
                attachments.sorted { $0.createdAt < $1.createdAt }
            }
    }
}

@Reducer
struct TimelineFeature {
    struct TimelineSection: Equatable, Identifiable {
        let date: Date
        var entries: [TimelineEntry]

        var id: Date { date }
    }

    @ObservableState
    struct State: Equatable {
        struct RowNumberCache: Equatable {
            var values: [UUID: Int] = [:]

            static func == (_ lhs: RowNumberCache, _ rhs: RowNumberCache) -> Bool {
                true
            }
        }

        var tasks: [RoutineTask] = []
        var logs: [RoutineLog] = []
        var events: [RoutineEvent] = []
        var emotionLogs: [EmotionLog] = []
        var notes: [RoutineNote] = []
        var focusSessions: [FocusSession] = []
        var sprintFocusSessions: [SprintFocusSessionRecord] = []
        var boardSprints: [BoardSprintRecord] = []
        var fileAttachmentTaskIDs: Set<UUID> = []
        var noteAttachmentNoteIDs: Set<UUID> = []
        var sleepSessions: [SleepSession] = []
        var placeCheckInSessions: [PlaceCheckInSession] = []
        var awaySessions: [AwaySession] = []
        var selectedRange: TimelineRange = .all
        var filterType: TimelineFilterType = .all
        var selectedTag: String?
        var selectedTags: Set<String> = []
        var includeTagMatchMode: RoutineTagMatchMode = .all
        var excludedTags: Set<String> = []
        var excludeTagMatchMode: RoutineTagMatchMode = .any
        var selectedFlags: Set<String> = []
        var includeFlagMatchMode: RoutineTagMatchMode = .all
        var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell? = nil
        var mediaFilter: TaskMediaFilter = .all
        var isFilterSheetPresented: Bool = false
        var availableTags: [String] = []
        var availableExcludeTags: [String] = []
        var availableFlags: [String] = []
        var flagRules: [RoutineFlagRule] = []
        var relatedTagRules: [RoutineRelatedTagRule] = []
        var groupedEntries: [TimelineSection] = []
        var visibleEntryIDs: [UUID] = []
        var visibleEntryIDSet: Set<UUID> = []
        var visibleEntriesByID: [UUID: TimelineEntry] = [:]
        @ObservationStateIgnored var rowNumberCache = RowNumberCache()
        var presentationRevision: UInt = 0
        var hasAnyTimelineRecords = false
        var deepLinkedNoteID: UUID?
        var deepLinkedEventID: UUID?

        var rowNumbersByEntryID: [UUID: Int] {
            rowNumberCache.values
        }

        var hasActiveFilters: Bool {
            selectedRange != .all
                || filterType != .all
                || !effectiveSelectedTags.isEmpty
                || !excludedTags.isEmpty
                || !selectedFlags.isEmpty
                || selectedImportanceUrgencyFilter != nil
                || mediaFilter != .all
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
            events: [RoutineEvent] = [],
            emotionLogs: [EmotionLog] = [],
            notes: [RoutineNote] = [],
            focusSessions: [FocusSession] = [],
            sprintFocusSessions: [SprintFocusSessionRecord] = [],
            boardSprints: [BoardSprintRecord] = [],
            sleepSessions: [SleepSession] = [],
            placeCheckInSessions: [PlaceCheckInSession] = [],
            awaySessions: [AwaySession] = [],
            fileAttachmentTaskIDs: Set<UUID> = [],
            noteAttachmentNoteIDs: Set<UUID> = []
        )
        case selectedRangeChanged(TimelineRange)
        case filterTypeChanged(TimelineFilterType)
        case selectedTagChanged(String?)
        case selectedTagsChanged(Set<String>)
        case includeTagMatchModeChanged(RoutineTagMatchMode)
        case excludedTagsChanged(Set<String>)
        case excludeTagMatchModeChanged(RoutineTagMatchMode)
        case selectedFlagsChanged(Set<String>)
        case includeFlagMatchModeChanged(RoutineTagMatchMode)
        case flagRulesChanged([RoutineFlagRule])
        case selectedImportanceUrgencyFilterChanged(ImportanceUrgencyFilterCell?)
        case mediaFilterChanged(TaskMediaFilter)
        case setFilterSheet(Bool)
        case clearFilters
        case openNoteDeepLink(UUID)
        case noteDeepLinkPresentationDismissed(UUID)
        case openEventDeepLink(UUID)
        case eventDeepLinkPresentationDismissed(UUID)
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date.now) var now
    @Dependency(\.appSettingsClient) var appSettingsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .setData(tasks, logs, events, emotionLogs, notes, focusSessions, sprintFocusSessions, boardSprints, sleepSessions, placeCheckInSessions, awaySessions, fileAttachmentTaskIDs, noteAttachmentNoteIDs):
                state.tasks = tasks
                state.logs = logs
                state.events = events
                state.emotionLogs = emotionLogs
                state.notes = notes
                state.focusSessions = focusSessions
                state.sprintFocusSessions = sprintFocusSessions
                state.boardSprints = boardSprints
                state.sleepSessions = sleepSessions
                state.placeCheckInSessions = placeCheckInSessions
                state.awaySessions = awaySessions
                state.fileAttachmentTaskIDs = fileAttachmentTaskIDs
                state.noteAttachmentNoteIDs = noteAttachmentNoteIDs
                state.hasAnyTimelineRecords = !logs.isEmpty
                    || tasks.contains { $0.lastDone != nil }
                    || !events.isEmpty
                    || !emotionLogs.isEmpty
                    || !notes.isEmpty
                    || !focusSessions.isEmpty
                    || !sprintFocusSessions.isEmpty
                    || !awaySessions.isEmpty
                    || !sleepSessions.isEmpty
                    || !placeCheckInSessions.isEmpty
                state.relatedTagRules = RoutineTagRelations.sanitized(
                    appSettingsClient.relatedTagRules()
                    + RoutineTagRelations.learnedRules(from: tasks.map(\.tags))
                )
                state.flagRules = RoutineFlagRules.sanitized(appSettingsClient.flagRules())
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

            case let .selectedFlagsChanged(flags):
                state.selectedFlags = Set(RoutineFlag.deduplicated(Array(flags)))
                refreshDerivedState(&state)
                return .none

            case let .includeFlagMatchModeChanged(mode):
                state.includeFlagMatchMode = mode
                refreshDerivedState(&state)
                return .none

            case let .flagRulesChanged(rules):
                state.flagRules = RoutineFlagRules.sanitized(rules)
                refreshDerivedState(&state)
                return .none

            case let .selectedImportanceUrgencyFilterChanged(filter):
                state.selectedImportanceUrgencyFilter = ImportanceUrgencyFilterCell.normalized(filter)
                refreshDerivedState(&state)
                return .none

            case let .mediaFilterChanged(filter):
                state.mediaFilter = filter
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
                state.selectedFlags = []
                state.includeFlagMatchMode = .all
                state.selectedImportanceUrgencyFilter = nil
                state.mediaFilter = .all
                refreshDerivedState(&state)
                return .none

            case let .openNoteDeepLink(noteID):
                guard appSettingsClient.notesEnabled() else { return .none }
                state.selectedRange = .all
                state.filterType = .notes
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedFlags = []
                state.includeFlagMatchMode = .all
                state.selectedImportanceUrgencyFilter = nil
                state.mediaFilter = .all
                state.isFilterSheetPresented = false
                state.deepLinkedNoteID = noteID
                state.deepLinkedEventID = nil
                refreshDerivedState(&state)
                return .none

            case let .noteDeepLinkPresentationDismissed(noteID):
                if state.deepLinkedNoteID == noteID {
                    state.deepLinkedNoteID = nil
                }
                return .none

            case let .openEventDeepLink(eventID):
                state.selectedRange = .all
                state.filterType = .events
                state.setSelectedTag(nil)
                state.includeTagMatchMode = .all
                state.excludedTags = []
                state.excludeTagMatchMode = .any
                state.selectedFlags = []
                state.includeFlagMatchMode = .all
                state.selectedImportanceUrgencyFilter = nil
                state.mediaFilter = .all
                state.isFilterSheetPresented = false
                state.deepLinkedNoteID = nil
                state.deepLinkedEventID = eventID
                refreshDerivedState(&state)
                return .none

            case let .eventDeepLinkPresentationDismissed(eventID):
                if state.deepLinkedEventID == eventID {
                    state.deepLinkedEventID = nil
                }
                return .none
            }
        }
    }

    private func refreshDerivedState(_ state: inout State) {
        let baseEntries = TimelineLogic.filteredEntries(
            logs: state.logs,
            tasks: state.tasks,
            events: state.events,
            emotionLogs: state.emotionLogs,
            notes: state.notes,
            focusSessions: state.focusSessions,
            sprintFocusSessions: state.sprintFocusSessions,
            boardSprints: state.boardSprints,
            sleepSessions: state.sleepSessions,
            placeCheckInSessions: state.placeCheckInSessions,
            awaySessions: state.awaySessions,
            fileAttachmentTaskIDs: state.fileAttachmentTaskIDs,
            noteAttachmentNoteIDs: state.noteAttachmentNoteIDs,
            range: state.selectedRange,
            filterType: state.filterType,
            mediaFilter: state.mediaFilter,
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
        state.availableFlags = TimelineLogic.availableFlags(from: importanceUrgencyFilteredEntries)
        state.selectedFlags = state.selectedFlags.filter {
            RoutineFlag.contains($0, in: state.availableFlags)
        }
        let flagVisibleEntries = TimelineLogic.entriesVisibleForFlags(
            importanceUrgencyFilteredEntries,
            selectedFlags: state.selectedFlags,
            includeFlagMatchMode: state.includeFlagMatchMode,
            rules: state.flagRules
        )

        state.availableTags = TimelineLogic.availableTags(from: flagVisibleEntries)
        state.setSelectedTags(state.effectiveSelectedTags.filter { RoutineTag.contains($0, in: state.availableTags) })
        state.availableExcludeTags = TimelineFilterPresentation(
            selectedTags: state.effectiveSelectedTags,
            excludedTags: state.excludedTags,
            includeTagMatchMode: state.includeTagMatchMode,
            availableTags: state.availableTags,
            relatedTagRules: state.relatedTagRules
        ).availableExcludeTags(from: flagVisibleEntries)
        state.excludedTags = state.excludedTags.filter {
            RoutineTag.contains($0, in: state.availableExcludeTags)
        }

        let entries = flagVisibleEntries.filter { entry in
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
        let groupedEntries = TimelineLogic.groupedByDay(entries: entries, calendar: calendar)
            .map { TimelineSection(date: $0.date, entries: $0.entries) }
        state.groupedEntries = groupedEntries
        state.rowNumberCache.values = TimelineLogic.rowNumbersByEntryID(
            groupedEntries: groupedEntries.map { (date: $0.date, entries: $0.entries) }
        )
        state.visibleEntryIDs = groupedEntries.flatMap { $0.entries.map(\.id) }
        state.visibleEntryIDSet = Set(state.visibleEntryIDs)
        state.visibleEntriesByID = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.id, $0) }
        )
        state.presentationRevision &+= 1
    }
}
