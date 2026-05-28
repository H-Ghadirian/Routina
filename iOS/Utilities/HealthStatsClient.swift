import ComposableArchitecture
import Foundation
@preconcurrency import HealthKit

enum HealthStatsAccessState: Equatable, Sendable {
    case unavailable
    case notRequested
    case ready
    case failed
}

struct HealthStatsClient: Sendable {
    var isHealthDataAvailable: @Sendable () -> Bool
    var hasRequestedAuthorization: @Sendable () -> Bool
    var setHasRequestedAuthorization: @Sendable (Bool) -> Void
    var requestAuthorization: @Sendable () async throws -> Bool
    var fetchSummary: @Sendable (DoneChartRange, Date, Calendar) async throws -> HealthStatsSummary
}

extension HealthStatsClient {
    static let live: HealthStatsClient = {
        let store = HealthStatsStore()
        return HealthStatsClient(
            isHealthDataAvailable: {
                HKHealthStore.isHealthDataAvailable()
            },
            hasRequestedAuthorization: {
                SharedDefaults.app.bool(forKey: HealthStatsDefaults.authorizationRequestedKey)
            },
            setHasRequestedAuthorization: { isRequested in
                SharedDefaults.app.set(isRequested, forKey: HealthStatsDefaults.authorizationRequestedKey)
            },
            requestAuthorization: {
                try await store.requestAuthorization()
            },
            fetchSummary: { range, referenceDate, calendar in
                try await store.fetchSummary(
                    range: range,
                    referenceDate: referenceDate,
                    calendar: calendar
                )
            }
        )
    }()

    static let noop = HealthStatsClient(
        isHealthDataAvailable: { false },
        hasRequestedAuthorization: { false },
        setHasRequestedAuthorization: { _ in },
        requestAuthorization: { false },
        fetchSummary: { _, referenceDate, _ in
            HealthStatsSummary(fetchedAt: referenceDate)
        }
    )
}

private enum HealthStatsClientKey: DependencyKey {
    static let liveValue = HealthStatsClient.live
    static let testValue = HealthStatsClient.noop
}

extension DependencyValues {
    var healthStatsClient: HealthStatsClient {
        get { self[HealthStatsClientKey.self] }
        set { self[HealthStatsClientKey.self] = newValue }
    }
}

private enum HealthStatsDefaults {
    static let authorizationRequestedKey = "appSettingHealthStatsAuthorizationRequested"
}

private enum HealthStatsClientError: LocalizedError {
    case unavailable
    case noReadableTypes

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Health data is not available on this device."
        case .noReadableTypes:
            return "Routina could not find readable Health data types."
        }
    }
}

private actor HealthStatsStore {
    private let store = HKHealthStore()

    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthStatsClientError.unavailable
        }

        let types = readableTypes()
        guard !types.isEmpty else {
            throw HealthStatsClientError.noReadableTypes
        }

        return try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: [], read: types) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: success)
            }
        }
    }

    func fetchSummary(
        range: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) async throws -> HealthStatsSummary {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthStatsClientError.unavailable
        }

        let interval = try dateInterval(
            for: range,
            referenceDate: referenceDate,
            calendar: calendar
        )

        let steps = try await cumulativeSum(
            identifier: .stepCount,
            unit: .count(),
            interval: interval
        )
        let activeEnergyKilocalories = try await cumulativeSum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            interval: interval
        )
        let walkingRunningDistanceMeters = try await cumulativeSum(
            identifier: .distanceWalkingRunning,
            unit: .meter(),
            interval: interval
        )
        let exerciseMinutes = try await cumulativeSum(
            identifier: .appleExerciseTime,
            unit: .minute(),
            interval: interval
        )

        return HealthStatsSummary(
            steps: steps,
            activeEnergyKilocalories: activeEnergyKilocalories,
            walkingRunningDistanceMeters: walkingRunningDistanceMeters,
            exerciseMinutes: exerciseMinutes,
            fetchedAt: referenceDate
        )
    }

    private func readableTypes() -> Set<HKObjectType> {
        Set([
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime)
        ].compactMap { $0 })
    }

    private func cumulativeSum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        interval: DateInterval
    ) async throws -> Double {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return 0
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: interval.start,
            end: interval.end,
            options: [.strictStartDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func dateInterval(
        for range: DoneChartRange,
        referenceDate: Date,
        calendar: Calendar
    ) throws -> DateInterval {
        let endDay = calendar.startOfDay(for: referenceDate)
        guard let start = calendar.date(
            byAdding: .day,
            value: -(range.trailingDayCount - 1),
            to: endDay
        ),
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) else {
            throw HealthStatsClientError.unavailable
        }

        return DateInterval(start: start, end: end)
    }
}
