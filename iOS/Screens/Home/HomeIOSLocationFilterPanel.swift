import SwiftUI

struct HomeIOSLocationFilterPanel: View {
    let isLocationAuthorized: Bool
    let places: [RoutinePlace]
    let placeFilterAllTitle: String
    let manualPlaceFilterDescription: String
    let locationStatusText: String
    @Binding var hideUnavailableRoutines: Bool
    @Binding var selectedPlaceID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            placePicker

            Text(manualPlaceFilterDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(locationStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .padding(.horizontal)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Label("Place Filtering", systemImage: "location.viewfinder")
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 0)

            if isLocationAuthorized {
                Toggle("Hide unavailable", isOn: $hideUnavailableRoutines)
                    .labelsHidden()
            }
        }
    }

    private var placePicker: some View {
        Picker("Place Filter", selection: $selectedPlaceID) {
            Text(placeFilterAllTitle).tag(Optional<UUID>.none)
            ForEach(places) { place in
                Text(place.displayName).tag(Optional(place.id))
            }
        }
        .pickerStyle(.menu)
    }
}
