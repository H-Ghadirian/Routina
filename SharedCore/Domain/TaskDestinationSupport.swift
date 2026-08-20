import Foundation

enum TaskDestinationMapProvider: CaseIterable, Identifiable, Sendable {
    case appleMaps
    case googleMaps

    var id: Self { self }

    var title: String {
        switch self {
        case .appleMaps:
            return "Apple Maps"
        case .googleMaps:
            return "Google Maps"
        }
    }

    var systemImage: String {
        switch self {
        case .appleMaps:
            return "map"
        case .googleMaps:
            return "globe"
        }
    }

    func url(address: String?, coordinate: LocationCoordinate) -> URL? {
        let query = (address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let coordinateText = "\(coordinate.latitude),\(coordinate.longitude)"

        switch self {
        case .appleMaps:
            var components = URLComponents(string: "https://maps.apple.com/")
            components?.queryItems = [
                URLQueryItem(name: "q", value: query.isEmpty ? coordinateText : query),
                URLQueryItem(name: "ll", value: coordinateText)
            ]
            return components?.url
        case .googleMaps:
            var components = URLComponents(string: "https://www.google.com/maps/search/")
            components?.queryItems = [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "query", value: query.isEmpty ? coordinateText : query)
            ]
            return components?.url
        }
    }
}
