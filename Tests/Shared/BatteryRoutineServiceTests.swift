import Foundation
import SwiftData
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

@MainActor
struct BatteryRoutineServiceTests {
    @Test
    func lowBatteryCreatesRedPinnedUrgentRoutine() throws {
        let context = makeInMemoryContext()
        let date = makeDate("2026-05-08T10:00:00Z")

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPhone,
                levelPercent: 12,
                isCharging: false,
                capturedAt: date
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        let task = try #require(try fetchBatteryRoutine(.iPhone, in: context))
        #expect(task.name == "Charge iPhone")
        #expect(task.scheduleMode == .softInterval)
        #expect(task.priority == .urgent)
        #expect(task.importance == .level4)
        #expect(task.urgency == .level4)
        #expect(task.color == .red)
        #expect(task.pinnedAt == date)
    }

    @Test
    func chargingClearsLowBatteryPresentation() throws {
        let context = makeInMemoryContext()
        let lowDate = makeDate("2026-05-08T10:00:00Z")
        let chargingDate = makeDate("2026-05-08T10:15:00Z")

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPad,
                levelPercent: 10,
                isCharging: false,
                capturedAt: lowDate
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )
        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPad,
                levelPercent: 10,
                isCharging: true,
                capturedAt: chargingDate
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        let task = try #require(try fetchBatteryRoutine(.iPad, in: context))
        #expect(task.priority == .none)
        #expect(task.importance == .level2)
        #expect(task.urgency == .level2)
        #expect(task.color == .none)
        #expect(task.pinnedAt == nil)
    }

    @Test
    func pausedBatteryRoutineIsNotAutomaticallyReactivated() throws {
        let context = makeInMemoryContext()
        let date = makeDate("2026-05-08T10:00:00Z")
        let task = RoutineTask(
            id: BatteryRoutineDeviceKind.mac.routineID,
            name: "Charge Mac",
            scheduleMode: .softInterval,
            pausedAt: date
        )
        context.insert(task)
        try context.save()

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .mac,
                levelPercent: 5,
                isCharging: false,
                capturedAt: date
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        #expect(task.priority == .none)
        #expect(task.color == .none)
        #expect(task.pinnedAt == nil)
        #expect(task.pausedAt == date)
    }

    private func fetchBatteryRoutine(
        _ kind: BatteryRoutineDeviceKind,
        in context: ModelContext
    ) throws -> RoutineTask? {
        let routineID = kind.routineID
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == routineID
            }
        )
        return try context.fetch(descriptor).first
    }
}
