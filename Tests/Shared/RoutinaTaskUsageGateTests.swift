import Foundation
import Testing
#if SWIFT_PACKAGE
@testable @preconcurrency import RoutinaAppSupport
#elseif os(macOS)
@testable @preconcurrency import RoutinaMacOSDev
#else
@testable @preconcurrency import Routina
#endif

struct RoutinaTaskUsageGateTests {
    @Test
    func freeEntitlementBlocksCreationAfterTenActiveTasks() {
        let tasks = (0..<10).map { index in
            RoutineTask(name: "Task \(index)", scheduleMode: .oneOff)
        }

        let snapshot = RoutinaTaskUsageGate.limitSnapshot(
            for: tasks,
            entitlement: .free
        )

        #expect(snapshot == RoutinaTaskLimitSnapshot(activeTaskCount: 10, freeTaskLimit: 10))
    }

    @Test
    func freeEntitlementAllowsCreationBelowTenActiveTasks() {
        let tasks = (0..<9).map { index in
            RoutineTask(name: "Task \(index)", scheduleMode: .oneOff)
        }

        let snapshot = RoutinaTaskUsageGate.limitSnapshot(
            for: tasks,
            entitlement: .free
        )

        #expect(snapshot == nil)
    }

    @Test
    func inactiveTasksDoNotCountTowardFreeLimit() {
        let now = Date(timeIntervalSince1970: 1000)
        let activeTasks = (0..<9).map { index in
            RoutineTask(name: "Active \(index)", scheduleMode: .oneOff)
        }
        let completedTodo = RoutineTask(
            name: "Done",
            scheduleMode: .oneOff,
            lastDone: now
        )
        let canceledTodo = RoutineTask(
            name: "Canceled",
            scheduleMode: .oneOff,
            canceledAt: now
        )
        let pausedRoutine = RoutineTask(
            name: "Paused",
            pausedAt: now
        )
        let snoozedRoutine = RoutineTask(
            name: "Snoozed",
            snoozedUntil: now.addingTimeInterval(86_400)
        )

        let count = RoutinaTaskUsageGate.activeTaskCount(
            in: activeTasks + [completedTodo, canceledTodo, pausedRoutine, snoozedRoutine],
            referenceDate: now
        )

        #expect(count == 9)
    }

    @Test
    func unlimitedEntitlementAllowsMoreThanTenActiveTasks() {
        let tasks = (0..<12).map { index in
            RoutineTask(name: "Task \(index)", scheduleMode: .oneOff)
        }

        let snapshot = RoutinaTaskUsageGate.limitSnapshot(
            for: tasks,
            entitlement: .unlimited(plan: .annual, productID: RoutinaSubscriptionPlan.annual.productID)
        )

        #expect(snapshot == nil)
    }
}

