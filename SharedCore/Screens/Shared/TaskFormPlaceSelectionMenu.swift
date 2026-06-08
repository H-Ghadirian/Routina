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

struct TaskFormPlaceOptionsView: View {
    let model: TaskFormModel

    var body: some View {
        if !model.availablePlaces.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.availablePlaces) { place in
                    TaskFormPlaceOptionRow(
                        place: place,
                        isSelected: model.selectedPlaceIDsValue.contains(place.id)
                    ) {
                        model.toggleSelectedPlace(place.id)
                    }
                }
            }
        }
    }
}

private struct TaskFormPlaceOptionRow: View {
    let place: RoutinePlaceSummary
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let kind = place.kind {
                        Text(kind)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}
