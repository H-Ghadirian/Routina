#if os(macOS)
import ComposableArchitecture
import SwiftUI

struct RoutineDetailEditRoutineContent: View {
    let store: StoreOf<RoutineDetailFeature>
    @Binding var isEditEmojiPickerPresented: Bool
    let emojiOptions: [String]

    private var sectionHeaderFont: Font { .headline.weight(.semibold) }

    private var sectionCardBackground: some ShapeStyle {
        Color(nsColor: .controlBackgroundColor)
    }

    private var sectionCardStroke: Color {
        Color.gray.opacity(0.18)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionCard(title: "Basic") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField(
                                "Routine name",
                                text: Binding(
                                    get: { store.editRoutineName },
                                    set: { store.send(.editRoutineNameChanged($0)) }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Emoji")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 12) {
                                Text(store.editRoutineEmoji)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle()
                                            .fill(Color.blue.opacity(0.15))
                                    )
                                Button("Change Emoji") {
                                    isEditEmojiPickerPresented = true
                                }
                                .buttonStyle(.bordered)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }

                sectionCard(title: "Schedule") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Frequency")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                            .labelsHidden()
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repeat")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                    }
                }

                sectionCard(title: "Danger Zone") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(role: .destructive) {
                            store.send(.setDeleteConfirmation(true))
                        } label: {
                            Text("Delete Routine")
                        }
                        .buttonStyle(.borderless)

                        Text("This action cannot be undone.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 520, minHeight: 460)
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(sectionHeaderFont)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(sectionCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(sectionCardStroke, lineWidth: 1)
        )
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
