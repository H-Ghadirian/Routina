import Foundation

enum AddRoutineFormEditor {
    static func setDeadlineEnabled(
        _ isEnabled: Bool,
        now: Date,
        basics: inout AddRoutineBasicsState
    ) {
        basics.deadline = isEnabled ? (basics.deadline ?? now) : nil
    }

    static func setReminderEnabled(
        _ isEnabled: Bool,
        now: Date,
        basics: inout AddRoutineBasicsState
    ) {
        basics.reminderAt = isEnabled ? (basics.reminderAt ?? now) : nil
    }

    static func setTaskType(
        _ taskType: RoutineTaskType,
        basics: inout AddRoutineBasicsState,
        schedule: inout AddRoutineScheduleState
    ) {
        switch taskType {
        case .routine:
            if schedule.scheduleMode == .oneOff {
                schedule.scheduleMode = .fixedInterval
            }
            basics.deadline = nil
        case .todo:
            schedule.scheduleMode = .oneOff
        }
    }

    static func setAvailablePlaces(
        _ places: [RoutinePlaceSummary],
        basics: inout AddRoutineBasicsState,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availablePlaces = places
        if let selectedPlaceID = basics.selectedPlaceID,
           !places.contains(where: { $0.id == selectedPlaceID }) {
            basics.selectedPlaceID = nil
        }
    }

    static func setSelectedPlace(
        _ placeID: UUID?,
        basics: inout AddRoutineBasicsState
    ) {
        basics.selectedPlaceID = placeID
    }
}
