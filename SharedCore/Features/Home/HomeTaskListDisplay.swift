import Foundation

protocol HomeTaskListDisplay {
    var taskID: UUID { get }
    var name: String { get }
    var emoji: String { get }
    var taskDescription: String? { get }
    var notes: String? { get }
    var hasImage: Bool { get }
    var hasFileAttachment: Bool { get }
    var placeID: UUID? { get }
    var placeIDs: [UUID] { get }
    var placeName: String? { get }
    var tags: [String] { get }
    var flags: [String] { get }
    var taskListTagSectionDescriptor: HomeTaskListTagSectionDescriptor { get }
    var goalTitles: [String] { get }
    var interval: Int { get }
    var recurrenceRule: RoutineRecurrenceRule { get }
    var scheduleMode: RoutineScheduleMode { get }
    var trackingCadenceEnabled: Bool { get }
    var estimatedDurationMinutes: Int? { get }
    var createdAt: Date? { get }
    var lastDone: Date? { get }
    var lastSatisfiedScheduledOccurrenceAt: Date? { get }
    var dueDate: Date? { get }
    var plannedDate: Date? { get }
    var customTaskSectionID: UUID? { get }
    var priority: RoutineTaskPriority { get }
    var importance: RoutineTaskImportance { get }
    var urgency: RoutineTaskUrgency { get }
    var pressure: RoutineTaskPressure { get }
    var thinkingNeeded: RoutineTaskThinkingNeeded { get }
    var scheduleAnchor: Date? { get }
    var pausedAt: Date? { get }
    var pinnedAt: Date? { get }
    var daysUntilDue: Int { get }
    var hasMissedExactTimedOccurrence: Bool { get }
    var isOneOffTask: Bool { get }
    var isCompletedOneOff: Bool { get }
    var isCanceledOneOff: Bool { get }
    var isDoneToday: Bool { get }
    var isCanceledToday: Bool { get }
    var isAssumedDoneToday: Bool { get }
    var isPaused: Bool { get }
    var isPinned: Bool { get }
    var isInProgress: Bool { get }
    var blocksManualCompletionForIncompleteChecklist: Bool { get }
    var completedChecklistItemCount: Int { get }
    var hasDailyRunoutChecklistItem: Bool { get }
    var manualSectionOrders: [String: Int] { get }
    var todoState: TodoState? { get }
}

extension HomeTaskListDisplay {
    var flags: [String] {
        []
    }

    var taskDescription: String? {
        nil
    }

    var hasMissedExactTimedOccurrence: Bool {
        false
    }

    var hasImage: Bool {
        false
    }

    var hasFileAttachment: Bool {
        false
    }

    var trackingCadenceEnabled: Bool {
        true
    }

    var estimatedDurationMinutes: Int? {
        nil
    }

    var thinkingNeeded: RoutineTaskThinkingNeeded {
        .none
    }

    var lastSatisfiedScheduledOccurrenceAt: Date? {
        nil
    }

    var plannedDate: Date? {
        nil
    }

    var customTaskSectionID: UUID? {
        nil
    }

    var hasDailyRunoutChecklistItem: Bool {
        false
    }

    var isAssumedDoneToday: Bool {
        false
    }

    var isCanceledToday: Bool {
        false
    }

    var blocksManualCompletionForIncompleteChecklist: Bool {
        false
    }

    var placeIDs: [UUID] {
        placeID.map { [$0] } ?? []
    }

    var isDailyRoutine: Bool {
        guard trackingCadenceEnabled else { return false }
        return RoutineTaskDailyRoutineSupport.isDailyRoutineForTaskList(
            isOneOffTask: isOneOffTask,
            scheduleMode: scheduleMode,
            recurrenceRule: recurrenceRule,
            hasDailyRunoutChecklistItem: hasDailyRunoutChecklistItem
        )
    }

    var taskListTagSectionDescriptor: HomeTaskListTagSectionDescriptor {
        HomeTaskListTagGrouping.descriptor(for: tags)
    }

    var taskListPrimaryTag: String? {
        taskListTagSectionDescriptor.primaryTag
    }

    var taskListTagSectionTitle: String {
        taskListTagSectionDescriptor.title
    }

    var taskListTagManualOrderSectionKey: String {
        taskListTagSectionDescriptor.sectionKey
    }

    func isFixedCalendarRoutineScheduled(on day: Date, calendar: Calendar) -> Bool {
        guard scheduleMode.taskType == .routine, !isOneOffTask, !isDailyRoutine else { return false }
        return RoutineDateMath.isFixedCalendarOccurrence(
            for: recurrenceRule,
            on: day,
            calendar: calendar
        )
    }

    func hasSatisfiedScheduledOccurrence(on day: Date, calendar: Calendar) -> Bool {
        guard let lastSatisfiedScheduledOccurrenceAt else { return false }
        return calendar.isDate(lastSatisfiedScheduledOccurrenceAt, inSameDayAs: day)
    }
}

enum HomeTaskListTagGrouping {
    static let untaggedTitle = "No Tags"

    static func primaryTag<Display: HomeTaskListDisplay>(for task: Display) -> String? {
        descriptor(for: task).primaryTag
    }

    static func descriptor<Display: HomeTaskListDisplay>(for task: Display) -> HomeTaskListTagSectionDescriptor {
        task.taskListTagSectionDescriptor
    }

    static func descriptor(for tags: [String]) -> HomeTaskListTagSectionDescriptor {
        for rawTag in tags {
            guard let cleanedTag = RoutineTag.cleaned(rawTag),
                  let normalizedTag = RoutineTag.normalized(cleanedTag) else {
                continue
            }
            return HomeTaskListTagSectionDescriptor(
                primaryTag: cleanedTag,
                title: "#\(cleanedTag)",
                sectionKey: "tag:\(normalizedTag)",
                isUntagged: false
            )
        }

        return HomeTaskListTagSectionDescriptor(
            primaryTag: nil,
            title: untaggedTitle,
            sectionKey: "tag:untagged",
            isUntagged: true
        )
    }

    static func sectionTitle(for tag: String?) -> String {
        guard let tag else { return untaggedTitle }
        return "#\(tag)"
    }

    static func sectionKey(for tag: String?) -> String {
        guard let tag, let normalizedTag = RoutineTag.normalized(tag) else {
            return "tag:untagged"
        }
        return "tag:\(normalizedTag)"
    }

    static func isUntaggedTitle(_ title: String) -> Bool {
        title == untaggedTitle
    }
}

struct HomeTaskListTagSectionDescriptor: Equatable {
    let primaryTag: String?
    let title: String
    let sectionKey: String
    let isUntagged: Bool
}

struct HomeTaskListSection<Display: HomeTaskListDisplay> {
    let identityKey: String
    let title: String
    var tasks: [Display]

    init(identityKey: String, title: String, tasks: [Display]) {
        self.identityKey = identityKey
        self.title = title
        self.tasks = tasks
    }
}

extension HomeTaskListSection: Equatable where Display: Equatable {}

struct HomeTaskListFilteringConfiguration {
    var selectedFilter: RoutineListFilter
    var advancedQuery: String
    var selectedManualPlaceFilterID: UUID?
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var selectedTodoStateFilter: TodoState?
    var selectedPressureFilter: RoutineTaskPressure?
    var selectedThinkingNeededFilter: RoutineTaskThinkingNeeded? = nil
    var selectedGoalFilter: HomeTaskGoalFilter
    var selectedMediaFilter: TaskMediaFilter
    var selectedEstimationFilter: TaskEstimationFilter
    var hideAssumedDoneTasks: Bool
    var taskListViewMode: HomeTaskListViewMode
    var taskListSortOrder: HomeTaskListSortOrder
    var createdDateFilter: HomeTaskCreatedDateFilter
    var selectedTags: Set<String>
    var includeTagMatchMode: RoutineTagMatchMode
    var selectedFlags: Set<String> = []
    var includeFlagMatchMode: RoutineTagMatchMode = .all
    var excludedTags: Set<String>
    var excludeTagMatchMode: RoutineTagMatchMode
    var searchText: String
    var routineListSectioningMode: RoutineListSectioningMode
    var separateDeadlineStatusInTagSections: Bool = false
    var flagRules: [RoutineFlagRule] = []
    var routineTasks: [RoutineTask]
    var referenceDate: Date
    var calendar: Calendar
}
