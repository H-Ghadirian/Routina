import MapKit
import SwiftUI

struct TaskDestinationFormEditor: View {
    let address: Binding<String>
    let coordinate: Binding<LocationCoordinate?>

    @State private var isSearching = false
    @State private var searchMessage: String?
    @State private var resolvedAddress = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Street address or place", text: address, axis: .vertical)
                .lineLimit(1...3)
                .onChange(of: address.wrappedValue) { _, newValue in
                    guard !resolvedAddress.isEmpty, newValue != resolvedAddress else { return }
                    coordinate.wrappedValue = nil
                    resolvedAddress = ""
                }

            HStack(spacing: 10) {
                Button {
                    findDestination()
                } label: {
                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                        Text("Finding…")
                    } else {
                        Label("Find on map", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isSearching || address.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if coordinate.wrappedValue != nil {
                    Label("Map location set", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer(minLength: 0)

                if address.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Button("Clear", role: .destructive) {
                        address.wrappedValue = ""
                        coordinate.wrappedValue = nil
                        resolvedAddress = ""
                        searchMessage = nil
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let searchMessage {
                Text(searchMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Use Find on map to attach coordinates for the task map and navigation buttons.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            resolvedAddress = address.wrappedValue
        }
    }

    private func findDestination() {
        let query = address.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        isSearching = true
        searchMessage = nil

        Task { @MainActor in
            defer { isSearching = false }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query

            do {
                let response = try await MKLocalSearch(request: request).start()
                guard let item = response.mapItems.first else {
                    searchMessage = "No matching location was found. You can keep the address without a map pin."
                    coordinate.wrappedValue = nil
                    return
                }

                let mapCoordinate = item.location.coordinate
                guard mapCoordinate.latitude.isFinite,
                      mapCoordinate.longitude.isFinite
                else {
                    searchMessage = "This result did not include a usable map location."
                    coordinate.wrappedValue = nil
                    return
                }

                resolvedAddress = query
                address.wrappedValue = query
                coordinate.wrappedValue = LocationCoordinate(
                    latitude: mapCoordinate.latitude,
                    longitude: mapCoordinate.longitude
                )
                searchMessage = nil
            } catch {
                coordinate.wrappedValue = nil
                searchMessage = "Location search failed. Check the address and try again."
            }
        }
    }
}

struct TaskFormIOSDestinationSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text("Address")) {
            TaskDestinationFormEditor(
                address: model.destinationAddress,
                coordinate: model.destinationCoordinate
            )
        }
    }
}
