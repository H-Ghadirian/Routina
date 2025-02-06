import SwiftUI
import ComposableArchitecture

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            NavigationView {
                Form {
                    Section(header: Text("Name")) {
                        TextField("Routine name", text: viewStore.binding(
                            get: \.routineName,
                            send: AddRoutineFeature.Action.routineNameChanged
                        ))
                    }

                    Section(header: Text("Frequency (days)")) {
                        Stepper(value: viewStore.binding(
                            get: \.frequency,
                            send: AddRoutineFeature.Action.frequencyChanged
                        ), in: 1...30) {
                            Text("\(viewStore.frequency) day(s)")
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
            }
        }
    }
}
