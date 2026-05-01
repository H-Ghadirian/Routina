import ComposableArchitecture
import SwiftUI

struct GoalsEditorSheet: View {
    let store: StoreOf<GoalsFeature>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                Form {
                    Section {
                        TextField("Title", text: titleBinding)

                        TextField("Emoji", text: emojiBinding)

                        TextField("Notes", text: notesBinding, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section {
                        Toggle("Target Date", isOn: targetDateEnabledBinding)

                        if let targetDate = store.editorDraft.targetDate {
                            DatePicker(
                                "Date",
                                selection: Binding(
                                    get: { targetDate },
                                    set: { store.send(.editorTargetDateChanged($0)) }
                                ),
                                displayedComponents: .date
                            )
                        }
                    }

                    Section {
                        Picker("Color", selection: colorBinding) {
                            ForEach(RoutineTaskColor.allCases, id: \.self) { color in
                                HStack {
                                    GoalColorSwatch(color: color)
                                    Text(color.displayName)
                                }
                                .tag(color)
                            }
                        }
                    }

                    if let validationMessage = store.validationMessage {
                        Section {
                            Text(validationMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .navigationTitle(store.editorDraft.id == nil ? "New Goal" : "Edit Goal")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.dismissEditor)
                            dismiss()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.saveEditorTapped)
                        }
                        .disabled(store.editorDraft.cleanedTitle == nil)
                    }
                }
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.title },
            set: { store.send(.editorTitleChanged($0)) }
        )
    }

    private var emojiBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.emoji },
            set: { store.send(.editorEmojiChanged($0)) }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.notes },
            set: { store.send(.editorNotesChanged($0)) }
        )
    }

    private var targetDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.editorDraft.hasTargetDate },
            set: { store.send(.editorTargetDateEnabledChanged($0)) }
        )
    }

    private var colorBinding: Binding<RoutineTaskColor> {
        Binding(
            get: { store.editorDraft.color },
            set: { store.send(.editorColorChanged($0)) }
        )
    }
}

struct GoalColorSwatch: View {
    var color: RoutineTaskColor

    var body: some View {
        Circle()
            .fill(color.swiftUIColor ?? Color.secondary.opacity(0.25))
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: color == .none ? 1 : 0)
            }
            .accessibilityHidden(true)
    }
}
