import Foundation

extension AddRoutineTCAView {
    var isSaveDisabled: Bool {
        store.isSaveDisabled
    }

    var nameValidationMessage: String? {
        store.organization.nameValidationMessage
    }

    var isAddTagDisabled: Bool {
        RoutineTag.parseDraft(store.organization.tagDraft).isEmpty
    }

    var isAddStepDisabled: Bool {
        RoutineStep.normalizedTitle(store.checklist.stepDraft) == nil
    }

    var isAddChecklistItemDisabled: Bool {
        RoutineChecklistItem.normalizedTitle(store.checklist.checklistItemDraftTitle) == nil
    }

    var formPresentation: TaskFormPresentation {
        TaskFormPresentation(
            taskType: store.taskType,
            scheduleMode: store.schedule.scheduleMode,
            recurrenceKind: store.schedule.recurrenceKind,
            recurrenceHasExplicitTime: store.schedule.recurrenceHasExplicitTime,
            recurrenceWeekday: store.schedule.recurrenceWeekday,
            recurrenceDayOfMonth: store.schedule.recurrenceDayOfMonth,
            importance: store.basics.importance,
            urgency: store.basics.urgency,
            hasAvailableTags: !store.organization.availableTags.isEmpty,
            hasAvailableGoals: !store.organization.availableGoals.isEmpty,
            goalDraft: store.organization.goalDraft,
            selectedPlaceName: selectedPlaceName,
            canAutoAssumeDailyDone: store.canAutoAssumeDailyDone
        )
    }

    var selectedPlaceName: String? {
        guard let selectedPlaceID = store.basics.selectedPlaceID else { return nil }
        return store.organization.availablePlaces.first { $0.id == selectedPlaceID }?.name
    }

    var isStepBasedMode: Bool {
        formPresentation.isStepBasedMode
    }

    var showsRepeatControls: Bool {
        formPresentation.showsRepeatControls
    }

    var taskTypeDescription: String {
        formPresentation.taskTypeDescription
    }

    var scheduleModeDescription: String {
        formPresentation.scheduleModeDescription
    }

    var checklistSectionDescription: String {
        formPresentation.checklistSectionDescription(includesDerivedChecklistDueDetail: true)
    }

    var placeSelectionDescription: String {
        formPresentation.placeSelectionDescription
    }

    var importanceUrgencyDescription: String {
        formPresentation.importanceUrgencyDescription(
            includesDerivedPriority: true,
            priority: store.basics.priority
        )
    }

    var stepsSectionDescription: String {
        formPresentation.stepsSectionDescription
    }

    var tagSectionHelpText: String {
        formPresentation.tagSectionHelpText
    }

    var notesHelpText: String {
        formPresentation.notesHelpText
    }

    var linkHelpText: String {
        formPresentation.linkHelpText
    }

    var weekdayOptions: [(id: Int, name: String)] {
        let symbols = Calendar.current.weekdaySymbols
        return symbols.enumerated().map { index, name in
            (id: index + 1, name: name)
        }
    }

    func checklistIntervalLabel(for intervalDays: Int) -> String {
        TaskFormPresentation.checklistIntervalLabel(for: intervalDays)
    }
}
