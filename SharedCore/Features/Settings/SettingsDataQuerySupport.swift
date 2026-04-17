import SwiftData

enum SettingsDataQueries {
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
        return RoutineTag.summaries(from: tasks)
    }

    static func hasDuplicatePlaceName(_ name: String, in context: ModelContext) throws -> Bool {
        guard let normalizedName = RoutinePlace.normalizedName(name) else { return false }
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        return places.contains { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }
    }
}
