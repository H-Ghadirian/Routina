import Foundation

protocol HomeTaskListDisplay {
    var taskID: UUID { get }
    var name: String { get }
    var emoji: String { get }
    var notes: String? { get }
    var hasImage: Bool { get }
    var hasFileAttachment: Bool { get }
    var placeID: UUID? { get }
    var placeName: String? { get }
    var tags: [String] { get }
    var goalTitles: [String] { get }
    var interval: Int { get }
    var recurrenceRule: RoutineRecurrenceRule { get }
    var scheduleMode: RoutineScheduleMode { get }
    var createdAt: Date? { get }
    var lastDone: Date? { get }
    var dueDate: Date? { get }
    var priority: RoutineTaskPriority { get }
    var importance: RoutineTaskImportance { get }
    var urgency: RoutineTaskUrgency { get }
    var pressure: RoutineTaskPressure { get }
    var scheduleAnchor: Date? { get }
    var pausedAt: Date? { get }
    var pinnedAt: Date? { get }
    var daysUntilDue: Int { get }
    var hasMissedExactTimedOccurrence: Bool { get }
    var isOneOffTask: Bool { get }
    var isCompletedOneOff: Bool { get }
    var isCanceledOneOff: Bool { get }
    var isDoneToday: Bool { get }
    var isPaused: Bool { get }
    var isPinned: Bool { get }
    var isInProgress: Bool { get }
    var completedChecklistItemCount: Int { get }
    var manualSectionOrders: [String: Int] { get }
    var todoState: TodoState? { get }
}

extension HomeTaskListDisplay {
    var hasMissedExactTimedOccurrence: Bool {
        false
    }

    var hasImage: Bool {
        false
    }

    var hasFileAttachment: Bool {
        false
    }

    var isDailyRoutine: Bool {
        !isOneOffTask && recurrenceRule.isDaily
    }

    var taskListPrimaryTag: String? {
        HomeTaskListTagGrouping.primaryTag(for: self)
    }

    var taskListTagSectionTitle: String {
        HomeTaskListTagGrouping.sectionTitle(for: taskListPrimaryTag)
    }

    var taskListTagManualOrderSectionKey: String {
        HomeTaskListTagGrouping.sectionKey(for: taskListPrimaryTag)
    }
}

enum HomeTaskListTagGrouping {
    static let untaggedTitle = "No Tags"

    static func primaryTag<Display: HomeTaskListDisplay>(for task: Display) -> String? {
        RoutineTag.deduplicated(task.tags).first
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

struct HomeTaskListSection<Display: HomeTaskListDisplay> {
    let title: String
    var tasks: [Display]
}

extension HomeTaskListSection: Equatable where Display: Equatable {}

struct HomeTaskListFilteringConfiguration {
    var selectedFilter: RoutineListFilter
    var advancedQuery: String
    var selectedManualPlaceFilterID: UUID?
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var selectedTodoStateFilter: TodoState?
    var selectedPressureFilter: RoutineTaskPressure?
    var selectedGoalFilter: HomeTaskGoalFilter
    var selectedMediaFilter: TaskMediaFilter
    var taskListViewMode: HomeTaskListViewMode
    var taskListSortOrder: HomeTaskListSortOrder
    var createdDateFilter: HomeTaskCreatedDateFilter
    var selectedTags: Set<String>
    var includeTagMatchMode: RoutineTagMatchMode
    var excludedTags: Set<String>
    var excludeTagMatchMode: RoutineTagMatchMode
    var searchText: String
    var routineListSectioningMode: RoutineListSectioningMode
    var routineTasks: [RoutineTask]
    var referenceDate: Date
    var calendar: Calendar
}
