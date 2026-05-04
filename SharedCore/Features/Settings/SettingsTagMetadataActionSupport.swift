import ComposableArchitecture
import Foundation

enum SettingsTagMetadataActionHandler {
    static func tagColorsLoaded(
        _ colors: [String: String],
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.loadedTagColors(colors, state: &state)
        return .none
    }

    static func relatedTagRulesLoaded(
        _ rules: [RoutineRelatedTagRule],
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.loadedRelatedTagRules(rules, state: &state)
        return .none
    }

    static func learnedRelatedTagRulesLoaded(
        _ rules: [RoutineRelatedTagRule],
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.loadedLearnedRelatedTagRules(rules, state: &state)
        return .none
    }

    static func tagSearchQueryChanged(
        _ query: String,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        state.tagSearchQuery = query
        return .none
    }

    static func relatedTagDraftChanged(
        tagName: String,
        draft: String,
        state: inout SettingsTagsState
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.updateRelatedTagDraft(
            tagName: tagName,
            draft: draft,
            state: &state
        )
        return .none
    }

    static func tagColorChanged(
        tagName: String,
        colorHex: String?,
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let colors = SettingsTagEditor.updateTagColor(
            tagName: tagName,
            colorHex: colorHex,
            state: &state
        )
        appSettingsClient.setTagColors(colors)
        return .none
    }

    static func saveRelatedTagsTapped(
        _ tagName: String,
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let rules = SettingsTagEditor.saveRelatedTags(for: tagName, state: &state)
        appSettingsClient.setRelatedTagRules(rules)
        return .none
    }

    static func addRelatedTagDraftSubmitted(
        tagName: String,
        draft: String,
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let rules = SettingsTagEditor.appendRelatedTagDraft(
            tagName: tagName,
            draft: draft,
            state: &state
        )
        appSettingsClient.setRelatedTagRules(rules)
        return .none
    }

    static func appendRelatedTagSuggestionTapped(
        tagName: String,
        suggestion: String,
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let rules = SettingsTagEditor.appendRelatedTagSuggestion(
            tagName: tagName,
            suggestion: suggestion,
            state: &state
        )
        appSettingsClient.setRelatedTagRules(rules)
        return .none
    }

    static func removeRelatedTagTapped(
        tagName: String,
        relatedTag: String,
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let rules = SettingsTagEditor.removeRelatedTag(
            relatedTag,
            from: tagName,
            state: &state
        )
        appSettingsClient.setRelatedTagRules(rules)
        return .none
    }
}
