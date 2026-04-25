import Foundation

protocol HomeTaskListDisplay {
    var taskID: UUID { get }
    var name: String { get }
    var emoji: String { get }
    var notes: String? { get }
    var placeID: UUID? { get }
    var placeName: String? { get }
    var tags: [String] { get }
    var interval: Int { get }
    var recurrenceRule: RoutineRecurrenceRule { get }
    var scheduleMode: RoutineScheduleMode { get }
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

struct HomeTaskListSection<Display: HomeTaskListDisplay> {
    let title: String
    var tasks: [Display]
}

extension HomeTaskListSection: Equatable where Display: Equatable {}

struct HomeTaskListFilteringConfiguration {
    var selectedFilter: RoutineListFilter
    var selectedManualPlaceFilterID: UUID?
    var selectedImportanceUrgencyFilter: ImportanceUrgencyFilterCell?
    var selectedTodoStateFilter: TodoState?
    var selectedPressureFilter: RoutineTaskPressure?
    var taskListViewMode: HomeTaskListViewMode
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
