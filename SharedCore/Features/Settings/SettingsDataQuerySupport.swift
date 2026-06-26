import Foundation
import SwiftData

enum SettingsDataQueries {
    @MainActor
    static func fetchDeviceSessionSummaries(in context: ModelContext) throws -> [RoutinaDeviceSessionSummary] {
        let currentInstallationID = DeviceActivityRecorder.currentInstallationID()
        let sessions = try context.fetch(FetchDescriptor<RoutinaDeviceSession>())
        return sessions
            .map { $0.summary(currentInstallationID: currentInstallationID) }
            .sorted { lhs, rhs in
                if lhs.isCurrentDevice != rhs.isCurrentDevice {
                    return lhs.isCurrentDevice
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
    }

    @MainActor
    static func fetchPlaceSummaries(in context: ModelContext) throws -> [RoutinePlaceSummary] {
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return RoutinePlace.summaries(from: places, linkedTo: tasks)
    }

    @MainActor
    static func loadCloudUsageEstimate(in context: ModelContext) -> CloudUsageEstimate {
        (try? CloudUsageEstimate.estimate(in: context)) ?? .zero
    }

    @MainActor
    static func fetchTagSummaries(in context: ModelContext) throws -> [RoutineTagSummary] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let notes = SharedDefaults.app[.appSettingNotesEnabled]
            ? try context.fetch(FetchDescriptor<RoutineNote>())
            : []
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        return RoutineTag.summaries(from: tasks, goals: goals, notes: notes, events: events)
    }

    @MainActor
    static func fetchTaskTagCollections(in context: ModelContext) throws -> [[String]] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        let notes = SharedDefaults.app[.appSettingNotesEnabled]
            ? try context.fetch(FetchDescriptor<RoutineNote>())
            : []
        let events = try context.fetch(FetchDescriptor<RoutineEvent>())
        return tasks.map(\.tags) + goals.map(\.tags) + notes.map(\.tags) + events.map(\.tags)
    }

    static func hasDuplicatePlaceName(
        _ name: String,
        excluding ignoredPlaceID: UUID? = nil,
        in context: ModelContext
    ) throws -> Bool {
        guard let normalizedName = RoutinePlace.normalizedName(name) else { return false }
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        return places.contains { place in
            place.id != ignoredPlaceID
                && RoutinePlace.normalizedName(place.name) == normalizedName
        }
    }
}
