import ComposableArchitecture
import Foundation
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

typealias AddRoutineSaveHandler = (AddRoutineSaveRequest) -> Effect<AddRoutineFeature.Action>

@MainActor
func makeState(
    basics: AddRoutineBasicsState = AddRoutineBasicsState(),
    organization: AddRoutineOrganizationState = AddRoutineOrganizationState(),
    schedule: AddRoutineScheduleState = AddRoutineScheduleState(),
    checklist: AddRoutineChecklistState = AddRoutineChecklistState()
) -> AddRoutineFeature.State {
    AddRoutineFeature.State(
        basics: basics,
        organization: organization,
        schedule: schedule,
        checklist: checklist
    )
}

@MainActor
func makeFeature(
    onSave: @escaping AddRoutineSaveHandler = { _ in .none },
    onCancel: @escaping () -> Effect<AddRoutineFeature.Action> = { .none }
) -> AddRoutineFeature {
    AddRoutineFeature(onSave: onSave, onCancel: onCancel)
}

@MainActor
func makeDelegateEchoFeature() -> AddRoutineFeature {
    makeFeature(
        onSave: { request in
            .send(.delegate(.didSave(request)))
        }
    )
}

func makeSaveRequest(
    name: String,
    frequencyInDays: Int,
    recurrenceRule: RoutineRecurrenceRule,
    emoji: String,
    notes: String? = nil,
    link: String? = nil,
    deadline: Date? = nil,
    isAllDay: Bool = false,
    routineDurationMode: RoutineDurationMode = .oneDay,
    availabilityStartDate: Date? = nil,
    availabilityEndDate: Date? = nil,
    reminderAt: Date? = nil,
    priority: RoutineTaskPriority = .medium,
    importance: RoutineTaskImportance = .level2,
    urgency: RoutineTaskUrgency = .level2,
    imageData: Data? = nil,
    voiceNote: RoutineVoiceNote? = nil,
    selectedPlaceID: UUID? = nil,
    selectedPlaceIDs: [UUID] = [],
    tags: [String] = [],
    eventIDs: [UUID] = [],
    relationships: [RoutineTaskRelationship] = [],
    steps: [RoutineStep] = [],
    scheduleMode: RoutineScheduleMode = .fixedInterval,
    checklistItems: [RoutineChecklistItem] = [],
    recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
    attachments: [AttachmentItem] = [],
    color: RoutineTaskColor = .none,
    autoAssumeDailyDone: Bool = false,
    estimatedDurationMinutes: Int? = nil,
    actualDurationMinutes: Int? = nil,
    storyPoints: Int? = nil,
    focusModeEnabled: Bool = false
) -> AddRoutineSaveRequest {
    AddRoutineSaveRequest(
        name: name,
        frequencyInDays: frequencyInDays,
        recurrenceRule: recurrenceRule,
        emoji: emoji,
        notes: notes,
        link: link,
        deadline: deadline,
        isAllDay: isAllDay,
        routineDurationMode: routineDurationMode,
        availabilityStartDate: availabilityStartDate,
        availabilityEndDate: availabilityEndDate,
        reminderAt: reminderAt,
        priority: priority,
        importance: importance,
        urgency: urgency,
        imageData: imageData,
        voiceNote: voiceNote,
        selectedPlaceID: selectedPlaceID,
        selectedPlaceIDs: selectedPlaceIDs,
        tags: tags,
        eventIDs: eventIDs,
        relationships: relationships,
        steps: steps,
        scheduleMode: scheduleMode,
        checklistItems: checklistItems,
        recurrenceTimeRangeRole: recurrenceTimeRangeRole,
        attachments: attachments,
        color: color,
        autoAssumeDailyDone: autoAssumeDailyDone,
        estimatedDurationMinutes: estimatedDurationMinutes,
        actualDurationMinutes: actualDurationMinutes,
        storyPoints: storyPoints,
        focusModeEnabled: focusModeEnabled
    )
}
