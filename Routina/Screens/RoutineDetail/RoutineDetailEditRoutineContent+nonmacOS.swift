#if !os(macOS)
import ComposableArchitecture
import SwiftUI

struct RoutineDetailEditRoutineContent: View {
    let store: StoreOf<RoutineDetailFeature>
    @Binding var isEditEmojiPickerPresented: Bool
    let emojiOptions: [String]

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField(
                    "Routine name",
                    text: Binding(
                        get: { store.editRoutineName },
                        set: { store.send(.editRoutineNameChanged($0)) }
                    )
                )
            }

            Section(header: Text("Emoji")) {
                HStack(spacing: 12) {
                    Text("Selected")
                        .foregroundColor(.secondary)
                    Text(store.editRoutineEmoji)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                    Spacer()
                    Button("Choose Emoji") {
                        isEditEmojiPickerPresented = true
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(emojiOptions, id: \.self) { emoji in
                            Button {
                                store.send(.editRoutineEmojiChanged(emoji))
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(store.editRoutineEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
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
                        get: { store.editFrequency },
                        set: { store.send(.editFrequencyChanged($0)) }
                    )
                ) {
                    ForEach(RoutineDetailFeature.EditFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Repeat")) {
                Stepper(
                    value: Binding(
                        get: { store.editFrequencyValue },
                        set: { store.send(.editFrequencyValueChanged($0)) }
                    ),
                    in: 1...365
                ) {
                    Text(
                        editStepperLabel(
                            frequency: store.editFrequency,
                            frequencyValue: store.editFrequencyValue
                        )
                    )
                }
            }

            Section {
                Button(role: .destructive) {
                    store.send(.setDeleteConfirmation(true))
                } label: {
                    Text("Delete Routine")
                }
            } footer: {
                Text("This action cannot be undone.")
            }
        }
    }

    private func editStepperLabel(
        frequency: RoutineDetailFeature.EditFrequency,
        frequencyValue: Int
    ) -> String {
        if frequencyValue == 1 {
            switch frequency {
            case .day: return "Everyday"
            case .week: return "Everyweek"
            case .month: return "Everymonth"
            }
        }
        return "Every \(frequencyValue) \(frequency.singularLabel)s"
    }
}
#endif
