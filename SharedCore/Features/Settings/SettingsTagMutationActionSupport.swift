import ComposableArchitecture
import Foundation
import SwiftData

enum SettingsTagMutationActionHandler {
    static func setDeleteTagConfirmation(
        _ isPresented: Bool,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.setDeleteConfirmation(isPresented, state: &state)
        return .none
    }

    static func setTagRenameSheet(
        _ isPresented: Bool,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.setRenameSheet(isPresented, state: &state)
        return .none
    }

    static func tagRenameDraftChanged(
        _ name: String,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.updateRenameDraft(name, state: &state)
        return .none
    }

    static func renameTagTapped(
        _ tagName: String,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsTagEditor.beginRename(tagName: tagName, state: &state) else {
            return .none
        }
        return .none
    }

    static func saveTagRenameTapped(
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard let request = SettingsTagEditor.prepareRename(state: &state) else {
            return .none
        }

        let updatedRules = RoutineTagRelations.replacing(
            request.originalTagName,
            with: request.cleanedName,
            in: appSettingsClient.relatedTagRules()
        )
        appSettingsClient.setRelatedTagRules(updatedRules)
        SettingsTagEditor.loadedRelatedTagRules(updatedRules, state: &state)

        let updatedColors = RoutineTagColors.replacing(
            request.originalTagName,
            with: request.cleanedName,
            in: appSettingsClient.tagColors()
        )
        appSettingsClient.setTagColors(updatedColors)
        SettingsTagEditor.loadedTagColors(updatedColors, state: &state)

        return SettingsTagExecution.rename(request, modelContext: modelContext)
    }

    static func deleteTagTapped(
        _ tagName: String,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        guard SettingsTagEditor.beginDelete(tagName: tagName, state: &state) else {
            return .none
        }
        return .none
    }

    static func deleteTagConfirmed(
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient,
        modelContext: @escaping @MainActor @Sendable () -> ModelContext
    ) -> Effect<SettingsFeature.Action> {
        guard let request = SettingsTagEditor.prepareDeleteConfirmation(state: &state) else {
            return .none
        }

        let updatedRules = RoutineTagRelations.removing(
            request.tagName,
            from: appSettingsClient.relatedTagRules()
        )
        appSettingsClient.setRelatedTagRules(updatedRules)
        SettingsTagEditor.loadedRelatedTagRules(updatedRules, state: &state)

        let updatedColors = RoutineTagColors.removing(
            request.tagName,
            from: appSettingsClient.tagColors()
        )
        appSettingsClient.setTagColors(updatedColors)
        SettingsTagEditor.loadedTagColors(updatedColors, state: &state)

        return SettingsTagExecution.delete(request, modelContext: modelContext)
    }

    static func tagOperationFinished(
        message: String,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.finishOperation(message: message, state: &state)
        return .none
    }
}
