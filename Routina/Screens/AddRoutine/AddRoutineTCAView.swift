import SwiftUI
import ComposableArchitecture

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState private var isRoutineNameFocused: Bool

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
