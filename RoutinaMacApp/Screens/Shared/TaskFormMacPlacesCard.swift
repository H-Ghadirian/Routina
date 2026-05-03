import Foundation
import SwiftUI

struct TaskFormMacPlacesCard: View {
    let model: TaskFormModel
    let onManagePlaces: () -> Void

    var body: some View {
        TaskFormMacSectionCard(title: "Places") {
            VStack(alignment: .leading, spacing: 18) {
                TaskFormMacControlBlock(title: "Place") {
                    Picker("Place", selection: model.selectedPlaceID) {
                        Text("Anywhere").tag(Optional<UUID>.none)
                        ForEach(model.availablePlaces) { place in
                            Text(place.name).tag(Optional(place.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                TaskFormMacControlBlock(title: "") {
                    Button {
                        onManagePlaces()
                    } label: {
                        Label("Manage Places", systemImage: "map")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
