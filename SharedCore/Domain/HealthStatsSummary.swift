import Foundation

struct HealthStatsSummary: Equatable, Sendable {
    var steps: Double
    var activeEnergyKilocalories: Double
    var walkingRunningDistanceMeters: Double
    var exerciseMinutes: Double
    var fetchedAt: Date

    init(
        steps: Double = 0,
        activeEnergyKilocalories: Double = 0,
        walkingRunningDistanceMeters: Double = 0,
        exerciseMinutes: Double = 0,
        fetchedAt: Date = .now
    ) {
        self.steps = steps
        self.activeEnergyKilocalories = activeEnergyKilocalories
        self.walkingRunningDistanceMeters = walkingRunningDistanceMeters
        self.exerciseMinutes = exerciseMinutes
        self.fetchedAt = fetchedAt
    }
}
