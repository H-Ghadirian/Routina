import SwiftUI

struct TaskFormPlaceSelectionMenu: View {
    let model: TaskFormModel

    var body: some View {
        Menu {
            Button {
                model.setSelectedPlaceIDs([])
            } label: {
                Label("Anywhere", systemImage: model.selectedPlaceIDsValue.isEmpty ? "checkmark" : "circle")
            }

            if !model.availablePlaces.isEmpty {
                Divider()
            }

            ForEach(model.availablePlaces) { place in
                Button {
                    model.toggleSelectedPlace(place.id)
                } label: {
                    Label(place.name, systemImage: model.selectedPlaceIDsValue.contains(place.id) ? "checkmark" : "circle")
                }
            }
        } label: {
            Label(model.selectedPlaceMenuTitle, systemImage: "mappin.and.ellipse")
        }
    }
}
