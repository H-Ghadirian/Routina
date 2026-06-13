import Foundation

enum AddRoutineNameValidator {
    static func validationMessage(
        for routineName: String,
        existingRoutineNames: [String]
    ) -> String? {
        guard let normalizedName = RoutineTask.normalizedName(routineName) else {
            return nil
        }

        let hasDuplicate = existingRoutineNames.contains { existingName in
            RoutineTask.normalizedName(existingName) == normalizedName
        }

        return hasDuplicate
            ? "A task with this name already exists."
            : nil
    }
}

enum AddRoutineChecklistValidator {
    static let missingRequiredChecklistItemMessage = "Enter at least one checklist item."

    static func validationMessage(
        scheduleMode: RoutineScheduleMode,
        checklistItems: [RoutineChecklistItem],
        checklistItemDraftTitle: String
    ) -> String? {
        guard scheduleMode.isRoutineModeRequiringChecklistItems else { return nil }
        if !RoutineChecklistItem.sanitized(checklistItems).isEmpty {
            return nil
        }
        if RoutineChecklistItem.normalizedTitle(checklistItemDraftTitle) != nil {
            return nil
        }
        return missingRequiredChecklistItemMessage
    }
}

enum AddRoutineValidationEditor {
    static func setRoutineName(
        _ name: String,
        state: inout AddRoutineFeatureState
    ) {
        state.basics.routineName = name
        refreshNameValidation(
            state: &state
        )
    }

    static func setExistingRoutineNames(
        _ names: [String],
        state: inout AddRoutineFeatureState
    ) {
        state.organization.existingRoutineNames = names
        refreshNameValidation(
            state: &state
        )
    }

    static func refreshNameValidation(state: inout AddRoutineFeatureState) {
        state.organization.nameValidationMessage = AddRoutineNameValidator.validationMessage(
            for: state.basics.routineName,
            existingRoutineNames: state.organization.existingRoutineNames
        )
    }

    static func refreshChecklistValidation(state: inout AddRoutineFeatureState) {
        state.checklist.checklistValidationMessage = AddRoutineChecklistValidator.validationMessage(
            scheduleMode: state.schedule.scheduleMode,
            checklistItems: state.checklist.routineChecklistItems,
            checklistItemDraftTitle: state.checklist.checklistItemDraftTitle
        )
    }

}
