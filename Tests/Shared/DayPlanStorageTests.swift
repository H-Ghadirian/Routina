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
struct DayPlanStorageTests {
    @Test
    func deleteBlocksForTaskIDsRemovesOnlyMatchingPlannerBlocks() throws {
        let context = makeInMemoryContext()
        let deletedTaskID = UUID()
        let keptTaskID = UUID()
        let dayKey = "2026-06-27"
        let nextDayKey = "2026-06-28"
        let deletedBlock = DayPlanBlock(
            id: UUID(),
            taskID: deletedTaskID,
            dayKey: dayKey,
            startMinute: 9 * 60,
            durationMinutes: 30,
            titleSnapshot: "Deleted task"
        )
        let keptBlock = DayPlanBlock(
            id: UUID(),
            taskID: keptTaskID,
            dayKey: dayKey,
            startMinute: 10 * 60,
            durationMinutes: 30,
            titleSnapshot: "Kept task"
        )
        let deletedNextDayBlock = DayPlanBlock(
            id: UUID(),
            taskID: deletedTaskID,
            dayKey: nextDayKey,
            startMinute: 11 * 60,
            durationMinutes: 30,
            titleSnapshot: "Deleted task tomorrow"
        )

        DayPlanStorage.saveBlocks([deletedBlock, keptBlock], forDayKey: dayKey, context: context)
        DayPlanStorage.saveBlocks([deletedNextDayBlock], forDayKey: nextDayKey, context: context)

        let deletedCount = try DayPlanStorage.deleteBlocks(forTaskIDs: Set([deletedTaskID]), context: context)
        try context.save()

        #expect(deletedCount == 2)
        #expect(DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context).map(\.id) == [keptBlock.id])
        #expect(DayPlanStorage.loadBlocks(forDayKey: nextDayKey, context: context).isEmpty)
    }
}
