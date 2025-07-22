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
        syncRelatedTagDrafts(state: &state)
        if let pendingTag = state.tagPendingDeletion,
           let updatedTag = tagSummary(named: pendingTag.name, in: tags) {
            state.tagPendingDeletion = updatedTag
        }
        if let pendingTag = state.tagPendingRename,
           let updatedTag = tagSummary(named: pendingTag.name, in: tags) {
            state.tagPendingRename = updatedTag
        }
    }

    static func loadedRelatedTagRules(
        _ rules: [RoutineRelatedTagRule],
        state: inout SettingsTagsState
    ) {
        state.relatedTagRules = RoutineTagRelations.sanitized(rules)
        syncRelatedTagDrafts(state: &state)
    }

    static func updateRelatedTagDraft(
        tagName: String,
        draft: String,
        state: inout SettingsTagsState
    ) {
        guard let key = RoutineTag.normalized(tagName) else { return }
        state.relatedTagDrafts[key] = draft
        state.tagStatusMessage = ""
    }

    static func saveRelatedTags(
        for tagName: String,
        state: inout SettingsTagsState
    ) -> [RoutineRelatedTagRule] {
        guard let key = RoutineTag.normalized(tagName),
              let cleanedTag = RoutineTag.cleaned(tagName) else {
            return state.relatedTagRules
        }

        let relatedTags = RoutineTag.parseDraft(state.relatedTagDrafts[key] ?? "")
        let withoutTag = state.relatedTagRules.filter {
            RoutineTag.normalized($0.tag) != key
        }
        state.relatedTagRules = RoutineTagRelations.sanitized(
            withoutTag + [RoutineRelatedTagRule(tag: cleanedTag, relatedTags: relatedTags)]
        )
        syncRelatedTagDrafts(state: &state)
        state.tagStatusMessage = relatedTags.isEmpty
            ? "Related tags cleared for #\(cleanedTag)."
            : "Related tags saved for #\(cleanedTag)."
        return state.relatedTagRules
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

    private static func syncRelatedTagDrafts(state: inout SettingsTagsState) {
        let rules = RoutineTagRelations.sanitized(state.relatedTagRules)
        state.relatedTagRules = rules

        var drafts: [String: String] = [:]
        for tag in state.savedTags {
            guard let key = RoutineTag.normalized(tag.name) else { continue }
            let rule = rules.first { RoutineTag.normalized($0.tag) == key }
            drafts[key] = rule.map { RoutineTag.serialize($0.relatedTags).replacingOccurrences(of: "\n", with: ", ") } ?? ""
        }
        state.relatedTagDrafts = drafts
    }
}
