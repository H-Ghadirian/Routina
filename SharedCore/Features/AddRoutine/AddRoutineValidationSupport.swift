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
}
