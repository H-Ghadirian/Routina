import ComposableArchitecture
import MapKit
import SwiftUI

struct TaskDetailDestinationSectionView: View {
    let address: String?
    let coordinate: LocationCoordinate?
    let background: Color
    let stroke: Color

    @Dependency(\.urlOpenerClient) private var urlOpenerClient

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Address")
                    .font(.headline)

                if let address {
                    Label(address, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .taskDetailCopyableText(address)
                }

                if let coordinate {
                    destinationMap(for: coordinate)

                    HStack(spacing: 8) {
                        ForEach(TaskDestinationMapProvider.allCases) { provider in
                            Button {
                                guard let url = provider.url(address: address, coordinate: coordinate) else { return }
                                urlOpenerClient.open(url)
                            } label: {
                                Label(provider.title, systemImage: provider.systemImage)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Label(
                        "Find this address on the task form to show a map and navigation buttons.",
                        systemImage: "map"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func destinationMap(for coordinate: LocationCoordinate) -> some View {
        let mapCoordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let region = MKCoordinateRegion(
            center: mapCoordinate,
            latitudinalMeters: 700,
            longitudinalMeters: 700
        )

        return Map(initialPosition: .region(region)) {
            Marker(address ?? "Destination", coordinate: mapCoordinate)
        }
        .frame(minHeight: 190, maxHeight: 260)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Map for task destination")
    }
}
