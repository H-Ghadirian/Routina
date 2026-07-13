import Foundation

enum AddRoutineBasicsEditor {
    static func setEmoji(
        _ emoji: String,
        basics: inout AddRoutineBasicsState
    ) {
        basics.routineEmoji = RoutineTask.sanitizedEmoji(emoji, fallback: basics.routineEmoji)
    }

    static func setNotes(
        _ notes: String,
        basics: inout AddRoutineBasicsState
    ) {
        basics.routineNotes = notes
    }

    static func setLink(
        _ link: String,
        basics: inout AddRoutineBasicsState
    ) {
        basics.routineLink = link
    }

    static func setDeadlineDate(
        _ deadline: Date,
        calendar: Calendar,
        basics: inout AddRoutineBasicsState
    ) {
        basics.deadline = basics.isAllDay
            ? calendar.startOfDay(for: deadline)
            : deadline
    }

    static func setAvailabilityStartDate(
        _ availabilityStartDate: Date?,
        calendar: Calendar,
        basics: inout AddRoutineBasicsState
    ) {
        let bounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: availabilityStartDate,
            endDate: basics.availabilityEndDate,
            calendar: calendar
        )
        basics.availabilityStartDate = bounds.startDate
        basics.availabilityEndDate = bounds.endDate
    }

    static func setAvailabilityEndDate(
        _ availabilityEndDate: Date?,
        calendar: Calendar,
        basics: inout AddRoutineBasicsState
    ) {
        let bounds = RoutineTask.normalizedAvailabilityDateBounds(
            startDate: basics.availabilityStartDate,
            endDate: availabilityEndDate,
            calendar: calendar
        )
        basics.availabilityStartDate = bounds.startDate
        basics.availabilityEndDate = bounds.endDate
    }

    static func setPlannedDate(
        _ plannedDate: Date?,
        calendar: Calendar,
        basics: inout AddRoutineBasicsState
    ) {
        basics.plannedDate = RoutineTask.normalizedPlannedDate(plannedDate, calendar: calendar)
    }

    static func setPriority(
        _ priority: RoutineTaskPriority,
        basics: inout AddRoutineBasicsState
    ) {
        basics.priority = priority
    }

    static func setImportance(
        _ importance: RoutineTaskImportance,
        basics: inout AddRoutineBasicsState
    ) {
        basics.importance = importance
        basics.priority = AddRoutinePriorityMatrix.priority(
            importance: importance,
            urgency: basics.urgency
        )
    }

    static func setUrgency(
        _ urgency: RoutineTaskUrgency,
        basics: inout AddRoutineBasicsState
    ) {
        basics.urgency = urgency
        basics.priority = AddRoutinePriorityMatrix.priority(
            importance: basics.importance,
            urgency: urgency
        )
    }

    static func setPressure(
        _ pressure: RoutineTaskPressure,
        basics: inout AddRoutineBasicsState
    ) {
        basics.pressure = pressure
    }

    static func setImage(
        _ data: Data?,
        basics: inout AddRoutineBasicsState
    ) {
        basics.imageData = data.flatMap(TaskImageProcessor.compressedImageData(from:))
    }

    static func removeImage(
        basics: inout AddRoutineBasicsState
    ) {
        basics.imageData = nil
    }

    static func setVoiceNote(
        _ voiceNote: RoutineVoiceNote?,
        basics: inout AddRoutineBasicsState
    ) {
        basics.voiceNote = voiceNote
    }

    static func addAttachment(
        data: Data,
        fileName: String,
        basics: inout AddRoutineBasicsState
    ) {
        basics.attachments.append(AttachmentItem(fileName: fileName, data: data))
    }

    static func removeAttachment(
        _ id: UUID,
        basics: inout AddRoutineBasicsState
    ) {
        basics.attachments.removeAll { $0.id == id }
    }

    static func setColor(
        _ color: RoutineTaskColor,
        basics: inout AddRoutineBasicsState
    ) {
        basics.routineColor = color
    }

    static func setEstimatedDurationMinutes(
        _ estimatedDurationMinutes: Int?,
        basics: inout AddRoutineBasicsState
    ) {
        basics.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
    }

    static func setActualDurationMinutes(
        _ actualDurationMinutes: Int?,
        basics: inout AddRoutineBasicsState
    ) {
        basics.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutes)
    }

    static func setStoryPoints(
        _ storyPoints: Int?,
        basics: inout AddRoutineBasicsState
    ) {
        basics.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
    }

    static func setFocusModeEnabled(
        _ isEnabled: Bool,
        basics: inout AddRoutineBasicsState
    ) {
        basics.focusModeEnabled = isEnabled
    }
}
