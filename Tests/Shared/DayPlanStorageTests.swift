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
    func loadingDuplicateBlockRecordsUsesTheMostRecentlyUpdatedBlockAndRepairsOnSave() throws {
        let context = makeInMemoryContext()
        let dayKey = "2026-08-06"
        let blockID = UUID()
        let taskID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_786_008_000)
        let updatedAt = createdAt.addingTimeInterval(60)
        let staleRecord = DayPlanBlockRecord(
            id: blockID,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: 11 * 60 + 27,
            durationMinutes: 15,
            titleSnapshot: "Focus",
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let currentRecord = DayPlanBlockRecord(
            id: blockID,
            taskID: taskID,
            dayKey: dayKey,
            startMinute: 11 * 60 + 27,
            durationMinutes: 45,
            titleSnapshot: "Focus",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(staleRecord)
        context.insert(currentRecord)
        try context.save()

        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)

        #expect(loadedBlocks.count == 1)
        #expect(loadedBlocks.first?.id == blockID)
        #expect(loadedBlocks.first?.durationMinutes == 45)

        DayPlanStorage.saveBlocks(loadedBlocks, forDayKey: dayKey, context: context)
        let persistedRecords = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
        #expect(persistedRecords.filter { $0.dayKey == dayKey && $0.id == blockID }.count == 1)
    }

    @Test
    func loadingDuplicateSemanticPlacementsUsesTheMostRecentlyUpdatedBlockAndRepairsOnSave() throws {
        let context = makeInMemoryContext()
        let dayKey = "2026-08-05"
        let taskID = UUID()
        let otherTaskID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_785_921_600)
        let staleBlockID = UUID()
        let currentBlockID = UUID()
        let distinctSlotBlockID = UUID()
        let otherTaskBlockID = UUID()

        context.insert(
            DayPlanBlockRecord(
                id: staleBlockID,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: 13 * 60,
                durationMinutes: 45,
                titleSnapshot: "Stale title",
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        context.insert(
            DayPlanBlockRecord(
                id: currentBlockID,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: 13 * 60,
                durationMinutes: 45,
                titleSnapshot: "Current title",
                createdAt: createdAt.addingTimeInterval(30),
                updatedAt: createdAt.addingTimeInterval(60)
            )
        )
        context.insert(
            DayPlanBlockRecord(
                id: distinctSlotBlockID,
                taskID: taskID,
                dayKey: dayKey,
                startMinute: 15 * 60,
                durationMinutes: 45,
                titleSnapshot: "Same task later",
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        context.insert(
            DayPlanBlockRecord(
                id: otherTaskBlockID,
                taskID: otherTaskID,
                dayKey: dayKey,
                startMinute: 13 * 60,
                durationMinutes: 45,
                titleSnapshot: "Other task",
                createdAt: createdAt,
                updatedAt: createdAt
            )
        )
        try context.save()

        let loadedBlocks = DayPlanStorage.loadBlocks(forDayKey: dayKey, context: context)

        #expect(loadedBlocks.count == 3)
        #expect(Set(loadedBlocks.map(\.id)) == Set([currentBlockID, distinctSlotBlockID, otherTaskBlockID]))
        #expect(loadedBlocks.first(where: { $0.id == currentBlockID })?.titleSnapshot == "Current title")
        #expect(!loadedBlocks.contains(where: { $0.id == staleBlockID }))

        DayPlanStorage.saveBlocks(loadedBlocks, forDayKey: dayKey, context: context)
        let persistedRecords = try context.fetch(FetchDescriptor<DayPlanBlockRecord>())
            .filter { $0.dayKey == dayKey }
        #expect(Set(persistedRecords.map(\.id)) == Set([currentBlockID, distinctSlotBlockID, otherTaskBlockID]))
    }

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
