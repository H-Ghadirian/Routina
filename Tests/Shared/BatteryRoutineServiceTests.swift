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

    @Test
    func completedLowBatteryRoutineStaysDismissedUntilBatteryRecovers() throws {
        let context = makeInMemoryContext()
        let lowDate = makeDate("2026-05-08T10:00:00Z")
        let doneDate = makeDate("2026-05-08T10:05:00Z")
        let repeatedLowDate = makeDate("2026-05-08T10:20:00Z")
        let recoveredDate = makeDate("2026-05-08T10:35:00Z")
        let laterLowDate = makeDate("2026-05-08T11:00:00Z")
        let secondDoneDate = makeDate("2026-05-08T11:05:00Z")

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPhone,
                levelPercent: 10,
                isCharging: false,
                capturedAt: lowDate
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        let completed = try RoutineLogHistory.advanceTask(
            taskID: BatteryRoutineDeviceKind.iPhone.routineID,
            completedAt: doneDate,
            context: context
        )
        let task = try #require(completed?.task)
        #expect(task.lastDone == doneDate)
        #expect(task.priority == .none)
        #expect(task.color == .none)
        #expect(task.pinnedAt == nil)

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPhone,
                levelPercent: 9,
                isCharging: false,
                capturedAt: repeatedLowDate
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        #expect(task.lastDone == doneDate)
        #expect(task.priority == .none)
        #expect(task.color == .none)
        #expect(task.pinnedAt == nil)

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPhone,
                levelPercent: 40,
                isCharging: true,
                capturedAt: recoveredDate
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        #expect(task.lastDone == nil)

        BatteryRoutineService.reconcile(
            snapshot: BatteryDeviceSnapshot(
                kind: .iPhone,
                levelPercent: 8,
                isCharging: false,
                capturedAt: laterLowDate
            ),
            in: context,
            monitoringEnabled: true,
            thresholdPercent: 20
        )

        #expect(task.priority == .urgent)
        #expect(task.color == .red)
        #expect(task.pinnedAt == laterLowDate)
        #expect(task.lastDone == nil)

        let secondCompletion = try RoutineLogHistory.advanceTask(
            taskID: BatteryRoutineDeviceKind.iPhone.routineID,
            completedAt: secondDoneDate,
            context: context
        )

        #expect(secondCompletion?.result == .ignoredAlreadyCompletedToday)
        #expect(task.lastDone == secondDoneDate)
        #expect(task.priority == .none)
        #expect(task.color == .none)
        #expect(task.pinnedAt == nil)
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
