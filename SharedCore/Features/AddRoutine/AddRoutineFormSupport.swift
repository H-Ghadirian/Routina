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
        }
    }

    static func setAllDay(
        _ isAllDay: Bool,
        now: Date,
        calendar: Calendar,
        scheduleMode: RoutineScheduleMode,
        basics: inout AddRoutineBasicsState
    ) {
        basics.isAllDay = isAllDay
        if isAllDay, scheduleMode == .oneOff, let deadline = basics.deadline {
            basics.deadline = calendar.startOfDay(for: deadline)
        }
    }

    static func setRoutineDurationMode(
        _ durationMode: RoutineDurationMode,
        basics: inout AddRoutineBasicsState
    ) {
        basics.routineDurationMode = durationMode
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
            if schedule.scheduleMode.taskType != .routine {
                schedule.scheduleMode = .fixedInterval
            }
            basics.deadline = nil
            basics.availabilityStartDate = nil
            basics.availabilityEndDate = nil
            basics.reminderAt = nil
        case .todo:
            schedule.scheduleMode = .oneOff
            basics.routineDurationMode = .oneDay
        case .record:
            schedule.scheduleMode = .record
            basics.deadline = nil
            basics.availabilityStartDate = nil
            basics.availabilityEndDate = nil
            basics.plannedDate = nil
            basics.reminderAt = nil
        }
    }

    static func setAvailablePlaces(
        _ places: [RoutinePlaceSummary],
        basics: inout AddRoutineBasicsState,
        organization: inout AddRoutineOrganizationState
    ) {
        organization.availablePlaces = places
        let availablePlaceIDs = Set(places.map(\.id))
        let currentPlaceIDs = basics.selectedPlaceIDs.isEmpty
            ? basics.selectedPlaceID.map { [$0] } ?? []
            : basics.selectedPlaceIDs
        let selectedPlaceIDs = currentPlaceIDs.filter { availablePlaceIDs.contains($0) }
        basics.selectedPlaceIDs = selectedPlaceIDs
        basics.selectedPlaceID = selectedPlaceIDs.first
    }

    static func setSelectedPlace(
        _ placeID: UUID?,
        basics: inout AddRoutineBasicsState
    ) {
        setSelectedPlaces(placeID.map { [$0] } ?? [], basics: &basics)
    }

    static func setSelectedPlaces(
        _ placeIDs: [UUID],
        basics: inout AddRoutineBasicsState
    ) {
        let sanitizedPlaceIDs = RoutinePlaceIDStorage.sanitized(placeIDs)
        basics.selectedPlaceIDs = sanitizedPlaceIDs
        basics.selectedPlaceID = sanitizedPlaceIDs.first
    }
}
