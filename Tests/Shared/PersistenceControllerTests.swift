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

struct PersistenceControllerTests {
    @Test
    func primaryInitializationFailure_abortsWhenExistingStoreIsPresent() {
        let strategy = PersistenceController.strategyAfterPrimaryInitializationFailure(
            inMemory: false,
            hasExistingPersistentStore: true
        )

        #expect(strategy == .abortToProtectExistingStore)
    }

    @Test
    func primaryInitializationFailure_retriesPrimaryStoreForFreshInstall() {
        let strategy = PersistenceController.strategyAfterPrimaryInitializationFailure(
            inMemory: false,
            hasExistingPersistentStore: false
        )

        #expect(strategy == .retryPrimaryPersistentStore)
    }

    @Test
    func primaryInitializationFailure_usesFallbacksForInMemoryMode() {
        let strategy = PersistenceController.strategyAfterPrimaryInitializationFailure(
            inMemory: true,
            hasExistingPersistentStore: true
        )

        #expect(strategy == .skipRetryAndUseFallbacks)
    }

    @Test
    func storeOpenFailureMessage_includesStorePathAndUnderlyingError() {
        let message = PersistenceController.storeOpenFailureMessage(
            underlyingError: TestPersistenceError.schemaMismatch,
            storePath: "/tmp/RoutinaModel.sqlite",
            diagnosticsPath: "/tmp/PersistenceFailure.txt"
        )

        #expect(message.contains("/tmp/RoutinaModel.sqlite"))
        #expect(message.contains("schema mismatch"))
        #expect(message.contains("will not fall back to a new empty store"))
        #expect(message.contains("/tmp/PersistenceFailure.txt"))
    }

    @Test
    func storeOpenFailureDiagnosticsReport_includesTimestampAndContext() {
        let message = PersistenceController.storeOpenFailureDiagnosticsReport(
            underlyingError: TestPersistenceError.schemaMismatch,
            storePath: "/tmp/RoutinaModel.sqlite",
            now: Date(timeIntervalSince1970: 1_713_456_789)
        )

        #expect(message.contains("Routina Persistence Failure Diagnostics"))
        #expect(message.contains("Store Path: /tmp/RoutinaModel.sqlite"))
        #expect(message.contains("Underlying Error: schema mismatch"))
        #expect(message.contains("Timestamp:"))
    }

    @Test
    func writeStoreOpenFailureDiagnostics_writesReadableFile() throws {
        let diagnosticsURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("PersistenceFailure.txt")

        let writtenURL = PersistenceController.writeStoreOpenFailureDiagnostics(
            underlyingError: TestPersistenceError.schemaMismatch,
            storePath: "/tmp/RoutinaModel.sqlite",
            diagnosticsURL: diagnosticsURL,
            now: Date(timeIntervalSince1970: 1_713_456_789)
        )

        #expect(writtenURL == diagnosticsURL)

        let contents = try String(contentsOf: diagnosticsURL, encoding: .utf8)
        #expect(contents.contains("Store Path: /tmp/RoutinaModel.sqlite"))
        #expect(contents.contains("Underlying Error: schema mismatch"))
    }

    @MainActor
    @Test
    func migrateLegacyRecurrenceRules_backfillsSwiftDataColumnsAndClearsJSON() throws {
        let container = try PersistenceController.makeLocalOnlyContainer(inMemory: true)
        let context = container.mainContext
        let legacyRule = RoutineRecurrenceRule.monthly(
            on: 21,
            timeRange: RoutineTimeRange(
                start: RoutineTimeOfDay(hour: 7, minute: 0),
                end: RoutineTimeOfDay(hour: 10, minute: 0)
            )
        )
        let task = RoutineTask(name: "Legacy breakfast", interval: 30)
        task.recurrenceStorageVersion = 0
        task.recurrenceRuleStorage = RoutineRecurrenceRuleStorage.serialize(legacyRule)
        context.insert(task)
        try context.save()

        let migratedCount = try PersistenceController.migrateLegacyRecurrenceRules(in: context)

        #expect(migratedCount == 1)
        #expect(task.recurrenceRule == legacyRule)
        #expect(task.recurrenceStorageVersion == 1)
        #expect(task.recurrenceKindRawValue == RoutineRecurrenceRule.Kind.monthlyDay.rawValue)
        #expect(task.recurrenceDayOfMonth == 21)
        #expect(task.recurrenceTimeRangeStartHour == 7)
        #expect(task.recurrenceTimeRangeEndHour == 10)
        #expect(task.recurrenceRuleStorage.isEmpty)
    }

    @MainActor
    @Test
    func normalizeChecklistItemIntervals_updatesOnlyNonRunoutChecklistItems() throws {
        let container = try PersistenceController.makeLocalOnlyContainer(inMemory: true)
        let context = container.mainContext
        let completionTask = RoutineTask(
            name: "Meal",
            scheduleMode: .softIntervalChecklist
        )
        completionTask.checklistItemsStorage = RoutineChecklistItemStorage.serialize([
            RoutineChecklistItem(title: "first meal", intervalDays: 3)
        ])
        let runoutTask = RoutineTask(
            name: "Groceries",
            checklistItems: [
                RoutineChecklistItem(title: "Bread", intervalDays: 3)
            ],
            scheduleMode: .derivedFromChecklist
        )
        context.insert(completionTask)
        context.insert(runoutTask)
        try context.save()

        let normalizedCount = try PersistenceController.normalizeChecklistItemIntervals(in: context)

        #expect(normalizedCount == 1)
        #expect(completionTask.checklistItems.map(\.intervalDays) == [1])
        #expect(runoutTask.checklistItems.map(\.intervalDays) == [3])
    }
}

private enum TestPersistenceError: LocalizedError {
    case schemaMismatch

    var errorDescription: String? {
        switch self {
        case .schemaMismatch:
            return "schema mismatch"
        }
    }
}
