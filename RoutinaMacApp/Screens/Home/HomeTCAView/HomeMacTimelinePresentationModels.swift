import SwiftUI

@MainActor
final class HomeMacTimelinePresentationCache: ObservableObject {
    private var cachedSignature: HomeMacTimelinePresentationSignature?
    private var cachedPresentation: HomeMacTimelinePresentation?

    func presentation(
        for signature: HomeMacTimelinePresentationSignature,
        build: () -> HomeMacTimelinePresentation
    ) -> HomeMacTimelinePresentation {
        if cachedSignature == signature, let cachedPresentation {
            return cachedPresentation
        }
        #if os(macOS)
            if RoutinaMacScrollInteractionGate.isScrollActive, let cachedPresentation {
                return cachedPresentation
            }
        #endif

        let presentation = build()
        cachedSignature = signature
        cachedPresentation = presentation
        return presentation
    }

    func invalidate() {
        cachedSignature = nil
    }
}

struct HomeMacTimelinePresentationSignature: Equatable {
    let dataRevision: Int
    let filterType: TimelineFilterType
    let statusFilter: TimelineStatusFilter
    let mediaFilter: TaskMediaFilter
    let selectedTags: Set<String>
    let includeTagMatchMode: RoutineTagMatchMode
    let selectedFlags: Set<String>
    let includeFlagMatchMode: RoutineTagMatchMode
    let excludedFlags: Set<String>
    let excludeFlagMatchMode: RoutineTagMatchMode
    let excludedTags: Set<String>
    let excludeTagMatchMode: RoutineTagMatchMode
    let importanceUrgencyFilter: ImportanceUrgencyFilterCell?
    let pressureFilter: RoutineTaskPressure?
    let thinkingNeededFilter: RoutineTaskThinkingNeeded?
    let estimationFilter: TaskEstimationFilter
    let taskLadderReferenceDay: Date
    let searchText: String
    let showsEventsAndEmotions: Bool
    let showsPlaces: Bool
    let showsNotes: Bool
    let showsAway: Bool
    let showsSleep: Bool
    let flagRules: [RoutineFlagRule]
    let fileAttachmentTaskIDs: Set<UUID>
    let noteAttachmentNoteIDs: Set<UUID>
    let focusActionLogCount: Int
    let latestFocusActionLogTimestamp: Date?
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZoneIdentifier: String
    let calendarFirstWeekday: Int
    let calendarMinimumDaysInFirstWeek: Int
}

struct HomeMacTimelinePresentation {
    let baseEntries: [TimelineEntry]
    let filteredEntries: [TimelineEntry]
    let unfilteredEntries: [TimelineEntry]
    let availableFlags: [String]
    let groupedFilteredEntries: [(date: Date, entries: [TimelineEntry])]
    let rowNumbersByEntryID: [UUID: Int]
}

struct MacTimelineSelection {
    static var empty: MacTimelineSelection {
        MacTimelineSelection(
            entry: nil,
            emotion: nil,
            event: nil,
            note: nil,
            noteAttachments: [],
            placeCheckInSession: nil,
            awaySession: nil
        )
    }

    var entry: TimelineEntry?
    var emotion: EmotionLog?
    var event: RoutineEvent?
    var note: RoutineNote?
    var noteAttachments: [RoutineNoteAttachment]
    var placeCheckInSession: PlaceCheckInSession?
    var awaySession: AwaySession?
}
