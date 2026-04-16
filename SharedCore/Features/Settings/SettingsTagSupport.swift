import Foundation

struct SettingsTagRenameRequest: Equatable {
    var originalTagName: String
    var cleanedName: String
}

struct SettingsTagDeletionRequest: Equatable {
    var tagName: String
}

enum SettingsTagEditor {
    static func setDeleteConfirmation(
        _ isPresented: Bool,
        state: inout SettingsTagsState
    ) {
        state.isDeleteTagConfirmationPresented = isPresented
        if !isPresented {
            state.tagPendingDeletion = nil
        }
    }

    static func setRenameSheet(
        _ isPresented: Bool,
        state: inout SettingsTagsState
    ) {
        state.isTagRenameSheetPresented = isPresented
        if !isPresented {
            state.tagPendingRename = nil
            state.tagRenameDraft = ""
        }
    }

    static func loadedTags(
        _ tags: [RoutineTagSummary],
        state: inout SettingsTagsState
    ) {
        state.savedTags = tags
        if let pendingTag = state.tagPendingDeletion,
           let updatedTag = tagSummary(named: pendingTag.name, in: tags) {
            state.tagPendingDeletion = updatedTag
        }
        if let pendingTag = state.tagPendingRename,
           let updatedTag = tagSummary(named: pendingTag.name, in: tags) {
            state.tagPendingRename = updatedTag
        }
    }

    static func updateRenameDraft(
        _ name: String,
        state: inout SettingsTagsState
    ) {
        state.tagRenameDraft = name
        state.tagStatusMessage = ""
    }

    static func beginRename(
        tagName: String,
        state: inout SettingsTagsState
    ) -> Bool {
        guard !state.isTagOperationInProgress,
              let tag = tagSummary(named: tagName, in: state.savedTags) else {
            return false
        }

        state.tagPendingRename = tag
        state.tagRenameDraft = tag.name
        state.tagStatusMessage = ""
        state.isTagRenameSheetPresented = true
        return true
    }

    static func prepareRename(
        state: inout SettingsTagsState
    ) -> SettingsTagRenameRequest? {
        guard !state.isTagOperationInProgress else {
            return nil
        }
        guard let pendingTag = state.tagPendingRename else {
            return nil
        }
        guard let cleanedName = RoutineTag.cleaned(state.tagRenameDraft) else {
            state.tagStatusMessage = "Enter a tag name first."
            return nil
        }

        state.isTagRenameSheetPresented = false
        state.tagPendingRename = nil
        state.tagRenameDraft = ""
        state.isTagOperationInProgress = true
        state.tagStatusMessage = ""
        return SettingsTagRenameRequest(
            originalTagName: pendingTag.name,
            cleanedName: cleanedName
        )
    }

    static func beginDelete(
        tagName: String,
        state: inout SettingsTagsState
    ) -> Bool {
        guard !state.isTagOperationInProgress,
              let tag = tagSummary(named: tagName, in: state.savedTags) else {
            return false
        }

        state.tagPendingDeletion = tag
        state.tagStatusMessage = ""
        state.isDeleteTagConfirmationPresented = true
        return true
    }

    static func prepareDeleteConfirmation(
        state: inout SettingsTagsState
    ) -> SettingsTagDeletionRequest? {
        guard !state.isTagOperationInProgress,
              let pendingTag = state.tagPendingDeletion else {
            return nil
        }

        state.isDeleteTagConfirmationPresented = false
        state.tagPendingDeletion = nil
        state.isTagOperationInProgress = true
        state.tagStatusMessage = ""
        return SettingsTagDeletionRequest(tagName: pendingTag.name)
    }

    static func finishOperation(
        message: String,
        state: inout SettingsTagsState
    ) {
        state.isTagOperationInProgress = false
        state.tagStatusMessage = message
    }

    private static func tagSummary(
        named name: String,
        in tags: [RoutineTagSummary]
    ) -> RoutineTagSummary? {
        guard let normalizedTagName = RoutineTag.normalized(name) else { return nil }
        return tags.first { RoutineTag.normalized($0.name) == normalizedTagName }
    }
}
