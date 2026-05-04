import ComposableArchitecture
import Foundation

enum SettingsFastFilterActionHandler {
    static func tagsLoaded(
        _ tags: [RoutineTagSummary],
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        SettingsTagEditor.loadedTags(tags, state: &state)
        let fastFilterTags = FastFilterTags.sanitized(
            state.fastFilterTags.filter { tag in
                tags.contains { RoutineTag.contains($0.name, in: [tag]) }
            }
        )
        if fastFilterTags != state.fastFilterTags {
            state.fastFilterTags = fastFilterTags
            appSettingsClient.setFastFilterTags(fastFilterTags)
        }
        return .none
    }

    static func fastFilterTagsLoaded(
        _ tags: [String],
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let savedTags = state.savedTags
        let sanitizedTags = FastFilterTags.sanitized(tags)
        let fastFilterTags = sanitizedTags.filter { tag in
            savedTags.isEmpty || savedTags.contains { RoutineTag.contains($0.name, in: [tag]) }
        }
        state.fastFilterTags = fastFilterTags
        if fastFilterTags != sanitizedTags {
            appSettingsClient.setFastFilterTags(fastFilterTags)
        }
        return .none
    }

    static func fastFilterTagToggled(
        _ tag: String,
        state: inout SettingsTagsState,
        appSettingsClient: AppSettingsClient
    ) -> Effect<SettingsFeature.Action> {
        let updatedTags = FastFilterTags.toggling(tag, in: state.fastFilterTags)
        state.fastFilterTags = updatedTags
        appSettingsClient.setFastFilterTags(updatedTags)
        return .none
    }
}
