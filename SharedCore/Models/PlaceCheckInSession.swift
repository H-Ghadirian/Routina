import Foundation
import SwiftData

enum PlaceCheckInActivity: String, CaseIterable, Codable, Equatable, Identifiable, Sendable {
    case work
    case commute
    case errands
    case exercise
    case rest
    case social
    case other

    var id: Self { self }

    var title: String {
        switch self {
        case .work:
            return "Work"
        case .commute:
            return "Commute"
        case .errands:
            return "Errands"
        case .exercise:
            return "Exercise"
        case .rest:
            return "Rest"
        case .social:
            return "Social"
        case .other:
            return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .work:
            return "briefcase.fill"
        case .commute:
            return "car.fill"
        case .errands:
            return "bag.fill"
        case .exercise:
            return "figure.run"
        case .rest:
            return "cup.and.saucer.fill"
        case .social:
            return "person.2.fill"
        case .other:
            return "tag.fill"
        }
    }
}

@Model
final class PlaceCheckInSession {
    var id: UUID = UUID()
    var placeID: UUID?
    var placeName: String = ""
    var latitude: Double?
    var longitude: Double?
    var horizontalAccuracyMeters: Double?
    var placeRadiusMeters: Double?
    var activityRawValue: String?
    var note: String?
    var startedAt: Date?
    var endedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    var isActive: Bool {
        endedAt == nil
    }

    var activity: PlaceCheckInActivity? {
        get {
            guard let activityRawValue else { return nil }
            return PlaceCheckInActivity(rawValue: activityRawValue)
        }
        set {
            activityRawValue = newValue?.rawValue
            updatedAt = Date()
        }
    }

    var displayPlaceName: String {
        RoutinePlace.cleanedName(placeName) ?? "Unknown place"
    }

    var coordinate: LocationCoordinate? {
        guard let latitude, let longitude else { return nil }
        return LocationCoordinate(latitude: latitude, longitude: longitude)
    }

    init(
        id: UUID = UUID(),
        placeID: UUID?,
        placeName: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        horizontalAccuracyMeters: Double? = nil,
        placeRadiusMeters: Double? = nil,
        activity: PlaceCheckInActivity? = nil,
        note: String? = nil,
        startedAt: Date? = Date(),
        endedAt: Date? = nil,
        createdAt: Date? = Date(),
        updatedAt: Date? = Date()
    ) {
        self.id = id
        self.placeID = placeID
        self.placeName = RoutinePlace.cleanedName(placeName) ?? "Unknown place"
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracyMeters = horizontalAccuracyMeters.map { max($0, 0) }
        self.placeRadiusMeters = placeRadiusMeters.map { max($0, 0) }
        self.activityRawValue = activity?.rawValue
        self.note = Self.cleanedNote(note)
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func end(at endedAt: Date = Date()) {
        self.endedAt = max(endedAt, startedAt ?? endedAt)
        updatedAt = endedAt
    }

    func durationSeconds(referenceDate: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        let finish = endedAt ?? referenceDate
        return max(0, finish.timeIntervalSince(startedAt))
    }

    func detachedCopy() -> PlaceCheckInSession {
        PlaceCheckInSession(
            id: id,
            placeID: placeID,
            placeName: placeName,
            latitude: latitude,
            longitude: longitude,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            placeRadiusMeters: placeRadiusMeters,
            activity: activity,
            note: note,
            startedAt: startedAt,
            endedAt: endedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    static func cleanedNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension PlaceCheckInSession: Identifiable, Equatable {
    static func == (lhs: PlaceCheckInSession, rhs: PlaceCheckInSession) -> Bool {
        lhs.id == rhs.id
    }
}

enum PlaceCheckInFormatting {
    static func durationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)m"
        }
        if minutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(minutes)m"
    }
}
