import Foundation

protocol HomeRoutineMetadataDisplay: HomeTaskRowDisplay {
    var locationAvailability: RoutineLocationAvailability { get }
    var canceledAt: Date? { get }
    var isSoftIntervalRoutine: Bool { get }
    var isAssumedDoneToday: Bool { get }
    var isSnoozed: Bool { get }
    var isOngoing: Bool { get }
    var ongoingSince: Date? { get }
    var hasPassedSoftThreshold: Bool { get }
    var completedStepCount: Int { get }
    var nextStepTitle: String? { get }
    var checklistItemCount: Int { get }
    var nextPendingChecklistItemTitle: String? { get }
    var nextDueChecklistItemTitle: String? { get }
    var doneCount: Int { get }
}
