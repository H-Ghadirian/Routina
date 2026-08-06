import ComposableArchitecture
import SwiftUI

struct TaskChoiceTagPreferencesView: View {
    let store: StoreOf<TaskChoiceTagPreferencesFeature>

    var body: some View {
        Group {
            if store.isLoading && store.tags.isEmpty {
                ProgressView("Loading tags…")
            } else if let errorMessage = store.errorMessage {
                ContentUnavailableView {
                    Label("Couldn’t load tag preferences", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try again") {
                        store.send(.onAppear)
                    }
                }
            } else if store.tags.isEmpty {
                ContentUnavailableView {
                    Label("No task tags yet", systemImage: "tag")
                } description: {
                    Text("Add tags to tasks, then choose the ones that should help Routina suggest what to do next.")
                }
            } else {
                tagList
            }
        }
        .navigationTitle("Tag preferences")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            store.send(.onAppear)
        }
        .toolbar {
            if store.enabledTagCount > 0 {
                Button("Reset learning") {
                    store.send(.resetLearnedScoresTapped)
                }
            }
        }
    }

    private var tagList: some View {
        List {
            Section {
                Text("Choose meaningful work tags. When equal tasks are compared, Routina learns which selected tags you tend to prefer. Task metadata is never changed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Use for suggestions") {
                ForEach(store.tags) { tag in
                    Toggle(isOn: Binding(
                        get: { tag.isEnabled },
                        set: { store.send(.tagToggled(tag: tag.name, isEnabled: $0)) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(tag.name)")
                                .font(.body.weight(.medium))
                            Text(summary(for: tag))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.accentColor)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func summary(for tag: TaskChoiceTagPreferencesFeature.State.Tag) -> String {
        let taskText = "\(tag.taskCount) task\(tag.taskCount == 1 ? "" : "s")"
        guard let preference = tag.preference, preference.comparisonCount > 0 else {
            return tag.isEnabled ? "\(taskText) • ready to learn" : taskText
        }
        return "\(taskText) • learned +\(preference.score.formatted(.number.precision(.fractionLength(1)))) from \(preference.comparisonCount) comparison\(preference.comparisonCount == 1 ? "" : "s")"
    }
}
