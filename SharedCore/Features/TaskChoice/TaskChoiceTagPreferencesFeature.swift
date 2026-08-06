import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
struct TaskChoiceTagPreferencesFeature {
    @ObservableState
    struct State: Equatable {
        struct Tag: Identifiable, Equatable {
            let name: String
            let taskCount: Int
            var preference: TaskChoiceTagPreference?

            var id: String { RoutineTag.normalized(name) ?? name }
            var isEnabled: Bool { preference != nil }
        }

        var tags: [Tag] = []
        var isLoading = false
        var errorMessage: String?

        var enabledTagCount: Int {
            tags.count(where: \.isEnabled)
        }
    }

    @CasePathable
    enum Action: Equatable {
        case onAppear
        case tagsLoaded([State.Tag])
        case tagsLoadFailed
        case tagToggled(tag: String, isEnabled: Bool)
        case resetLearnedScoresTapped
    }

    @Dependency(\.modelContext) private var modelContext
    @Dependency(\.appSettingsClient) private var appSettingsClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                return loadTags()

            case let .tagsLoaded(tags):
                state.tags = tags
                state.isLoading = false
                state.errorMessage = nil
                return .none

            case .tagsLoadFailed:
                state.isLoading = false
                state.errorMessage = "Couldn’t load tags. Try again."
                return .none

            case let .tagToggled(tag, isEnabled):
                let preferences = TaskChoiceTagPreferences.toggling(
                    tag: tag,
                    isEnabled: isEnabled,
                    in: appSettingsClient.taskChoiceTagPreferences()
                )
                appSettingsClient.setTaskChoiceTagPreferences(preferences)
                updatePresentation(&state, preferences: preferences)
                return .none

            case .resetLearnedScoresTapped:
                let preferences = TaskChoiceTagPreferences.resettingScores(
                    in: appSettingsClient.taskChoiceTagPreferences()
                )
                appSettingsClient.setTaskChoiceTagPreferences(preferences)
                updatePresentation(&state, preferences: preferences)
                return .none
            }
        }
    }

    private func loadTags() -> Effect<Action> {
        .run { @MainActor send in
            do {
                let tasks = try modelContext().fetch(FetchDescriptor<RoutineTask>())
                let preferences = TaskChoiceTagPreferences.sanitized(
                    appSettingsClient.taskChoiceTagPreferences()
                )
                let preferencesByTag = Dictionary(
                    uniqueKeysWithValues: preferences.map { ($0.id, $0) }
                )
                let tags = RoutineTag.summaries(from: tasks).map { summary in
                    State.Tag(
                        name: summary.name,
                        taskCount: summary.linkedRoutineCount,
                        preference: preferencesByTag[summary.id]
                    )
                }
                send(.tagsLoaded(tags))
            } catch {
                send(.tagsLoadFailed)
            }
        }
    }

    private func updatePresentation(
        _ state: inout State,
        preferences: [TaskChoiceTagPreference]
    ) {
        let preferencesByTag = Dictionary(
            uniqueKeysWithValues: TaskChoiceTagPreferences.sanitized(preferences).map { ($0.id, $0) }
        )
        state.tags = state.tags.map { tag in
            var updatedTag = tag
            updatedTag.preference = preferencesByTag[tag.id]
            return updatedTag
        }
    }
}
