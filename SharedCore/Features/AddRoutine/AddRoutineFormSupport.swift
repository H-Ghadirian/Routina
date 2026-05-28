import Foundation

enum AddRoutineFormEditor {
    static func setDeadlineEnabled(
        _ isEnabled: Bool,
        now: Date,
        basics: inout AddRoutineBasicsState
    ) {
        if isEnabled {
            basics.deadline = basics.deadline ?? now
        } else {
            basics.deadline = nil
            basics.isAllDay = false
        }
    }

    static func setAllDay(
        _ isAllDay: Bool,
        now: Date,
        calendar: Calendar,
        basics: inout AddRoutineBasicsState
    ) {
        basics.isAllDay = isAllDay
        if isAllDay {
            basics.deadline = calendar.startOfDay(for: basics.deadline ?? now)
        }
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
            basics.isAllDay = false
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
