import SwiftUI
import ComposableArchitecture

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState private var isRoutineNameFocused: Bool
    @State private var isEmojiPickerPresented = false
    private let emojiOptions = EmojiCatalog.quick
    private let allEmojiOptions = EmojiCatalog.all

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            NavigationView {
                Form {
                    Section(header: Text("Name")) {
                        TextField("Routine name", text: viewStore.binding(
                            get: \.routineName,
                            send: AddRoutineFeature.Action.routineNameChanged
                        ))
                        .focused($isRoutineNameFocused)
                    }

                    Section(header: Text("Emoji")) {
                        HStack(spacing: 12) {
                            Text("Selected")
                                .foregroundColor(.secondary)
                            Text(viewStore.routineEmoji)
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
                                        viewStore.send(.routineEmojiChanged(emoji))
                                    } label: {
                                        Text(emoji)
                                            .font(.title2)
                                            .frame(width: 40, height: 40)
                                            .background(
                                                Circle()
                                                    .fill(viewStore.routineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section(header: Text("Frequency")) {
                        Picker("Frequency", selection: viewStore.binding(
                            get: \.frequency,
                            send: AddRoutineFeature.Action.frequencyChanged
                        )) {
                            ForEach(AddRoutineFeature.Frequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(header: Text("Repeat")) {
                        Stepper(value: viewStore.binding(
                            get: \.frequencyValue,
                            send: AddRoutineFeature.Action.frequencyValueChanged
                        ), in: 1...365) {
                            Text(stepperLabel(for: viewStore))
                        }
                    }
                }
                .navigationTitle("Add Routine")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        viewStore.send(.cancelTapped)
                    },
                    trailing: Button("Save") {
                        viewStore.send(.saveTapped)
                    }
                    .disabled(viewStore.routineName.isEmpty)
                )
                .onAppear {
                    // Real devices can delay the first tap-to-focus inside Form.
                    // Auto-focus improves perceived responsiveness.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isRoutineNameFocused = true
                    }
                }
                .sheet(isPresented: $isEmojiPickerPresented) {
                    AddRoutineEmojiPickerSheet(
                        selectedEmoji: viewStore.binding(
                            get: \.routineEmoji,
                            send: AddRoutineFeature.Action.routineEmojiChanged
                        ),
                        emojis: allEmojiOptions
                    )
                }
            }
        }
    }

    private func stepperLabel(for viewStore: ViewStoreOf<AddRoutineFeature>) -> String {
        if viewStore.frequencyValue == 1 {
            switch viewStore.frequency {
            case .day:
                return "Everyday"
            case .week:
                return "Everyweek"
            case .month:
                return "Everymonth"
            }
        }

        let unit = viewStore.frequency.singularLabel
        return "Every \(viewStore.frequencyValue) \(unit)s"
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
                    ForEach(emojis, id: \.self) { emoji in
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
