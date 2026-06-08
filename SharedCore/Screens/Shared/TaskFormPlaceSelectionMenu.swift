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

struct TaskFormSelectedPlacesView: View {
    let model: TaskFormModel

    var body: some View {
        let summaries = model.selectedPlaceSummaries
        if !summaries.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(summaries) { place in
                    Button {
                        model.toggleSelectedPlace(place.id)
                    } label: {
                        Label(place.name, systemImage: "xmark.circle.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
}
