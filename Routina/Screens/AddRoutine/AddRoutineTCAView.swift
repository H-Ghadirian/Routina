import SwiftUI
import ComposableArchitecture

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>

    var body: some View {
        WithViewStore(store, observe: \.self) { viewStore in
            VStack {
                TextField("Routine name", text: viewStore.binding(
                    get: \.routineName,
                    send: AddRoutineFeature.Action.routineNameChanged
                ))
                .textFieldStyle(.roundedBorder)

                Button("Save") {
                    viewStore.send(.saveTapped)
                }
            }
            .padding()
        }
    }
}
