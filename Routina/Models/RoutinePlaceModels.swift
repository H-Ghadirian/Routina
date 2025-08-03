import CoreLocation
import Foundation
import SwiftData

struct RoutinePlaceSummary: Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var radiusMeters: Double
    var linkedRoutineCount: Int
}

enum RoutineLocationAvailability: Equatable, Sendable {
    case unrestricted
    case available(placeName: String)
    case away(placeName: String, distanceMeters: Double)
    case unknown(placeName: String)

    var placeName: String? {
        switch self {
        case .unrestricted:
            return nil
        case let .available(placeName),
             let .away(placeName, _),
             let .unknown(placeName):
            return placeName
        }
    }
}

@Model
final class RoutinePlace {
    var id: UUID = UUID()
    var name: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var radiusMeters: Double = 150
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double = 150,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = Self.cleanedName(name) ?? ""
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = max(radiusMeters, 25)
        self.createdAt = createdAt
    }

    func contains(_ coordinate: LocationCoordinate, graceMeters: Double = 75) -> Bool {
        distance(to: coordinate) <= max(radiusMeters, 25) + max(graceMeters, 0)
    }

    func distance(to coordinate: LocationCoordinate) -> Double {
        let placeLocation = CLLocation(latitude: latitude, longitude: longitude)
        let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return placeLocation.distance(from: userLocation)
    }

    func summary(linkedRoutineCount: Int = 0) -> RoutinePlaceSummary {
        RoutinePlaceSummary(
            id: id,
            name: displayName,
            radiusMeters: radiusMeters,
            linkedRoutineCount: linkedRoutineCount
        )
    }

    var displayName: String {
        Self.cleanedName(name) ?? "Unnamed place"
    }

    static func cleanedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func normalizedName(_ name: String?) -> String? {
        guard let cleaned = cleanedName(name) else { return nil }
        return cleaned.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}

extension RoutinePlace: Equatable {
    static func == (lhs: RoutinePlace, rhs: RoutinePlace) -> Bool {
        lhs.id == rhs.id
    }
}
