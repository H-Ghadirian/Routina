import SwiftUI
import ComposableArchitecture

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState private var isRoutineNameFocused: Bool
    @State private var isEmojiPickerPresented = false
    private let emojiOptions = EmojiCatalog.uniqueQuick
    private let allEmojiOptions = EmojiCatalog.uniqueAll

    var body: some View {
        WithPerceptionTracking {
            NavigationView {
                Form {
                    Section(header: Text("Name")) {
                        TextField(
                            "Routine name",
                            text: Binding(
                                get: { store.routineName },
                                set: { store.send(.routineNameChanged($0)) }
                            )
                        )
                        .focused($isRoutineNameFocused)
                    }

                    Section(header: Text("Emoji")) {
                        HStack(spacing: 12) {
                            Text("Selected")
                                .foregroundColor(.secondary)
                            Text(store.routineEmoji)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                            Spacer()
                            Button("Choose Emoji") {
                                isEmojiPickerPresented = true
                            }
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(emojiOptions, id: \.self) { emoji in
                                    Button {
                                        store.send(.routineEmojiChanged(emoji))
                                    } label: {
                                        Text(emoji)
                                            .font(.title2)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(store.routineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section(header: Text("Frequency")) {
                        Picker(
                            "Frequency",
                            selection: Binding(
                                get: { store.frequency },
                                set: { store.send(.frequencyChanged($0)) }
                            )
                        ) {
                            ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text("Repeat")) {
                        Stepper(
                            value: Binding(
                                get: { store.frequencyValue },
                                set: { store.send(.frequencyValueChanged($0)) }
                            ),
                            in: 1...365
                        ) {
                            Text(
                                stepperLabel(
                                    frequency: store.frequency,
                                    frequencyValue: store.frequencyValue
                                )
                            )
                        }
                    }
                }
                .navigationTitle("Add Routine")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            store.send(.cancelTapped)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.send(.saveTapped)
                        }
                        .disabled(store.routineName.isEmpty)
                    }
                }
                .onAppear {
                    // Real devices can delay the first tap-to-focus inside Form.
                    // Auto-focus improves perceived responsiveness.
                    #if !os(macOS)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isRoutineNameFocused = true
                    }
                    #endif
                }
                .sheet(isPresented: $isEmojiPickerPresented) {
                    AddRoutineEmojiPickerSheet(
                        selectedEmoji: Binding(
                            get: { store.routineEmoji },
                            set: { store.send(.routineEmojiChanged($0)) }
                        ),
                        emojis: allEmojiOptions
                    )
                }
            }
        }
    }

    private func stepperLabel(
        frequency: AddRoutineFeature.Frequency,
        frequencyValue: Int
    ) -> String {
        if frequencyValue == 1 {
            switch frequency {
            case .day:
                return "Everyday"
            case .week:
                return "Everyweek"
            case .month:
                return "Everymonth"
            }
        }

        let unit = frequency.singularLabel
        return "Every \(frequencyValue) \(unit)s"
    }
}

private struct AddRoutineEmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    let emojis: [String]
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(emojis.enumerated()), id: \.offset) { _, emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.title2)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Emoji")
            .routinaInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
