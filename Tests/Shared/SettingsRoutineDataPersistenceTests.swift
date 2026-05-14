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
struct SettingsRoutineDataPersistenceTests {
    @Test
    func writeBackup_toJSONURLWritesLegacyJSONFile() async throws {
        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Archive paperwork", tags: ["Admin"])
        context.insert(task)
        try context.save()

        let jsonURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.legacyJSONBackupExtension)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        try SettingsRoutineDataPersistence.writeBackup(to: jsonURL, from: context)

        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: jsonURL.path, isDirectory: &isDirectory))
        #expect(!isDirectory.boolValue)

        let backup = try SettingsRoutineDataBackupCoding.decodeBackup(
            from: Data(contentsOf: jsonURL)
        )
        #expect(backup.schemaVersion == SettingsRoutineDataPersistence.legacyJSONSchemaVersion)
        #expect(backup.tasks.map(\.id) == [task.id])
        #expect(backup.tasks.first?.tags == ["Admin"])
    }

    @Test
    func backupPackageAndRestore_preservesGoalHierarchy() async throws {
        let context = makeInMemoryContext()
        let parent = RoutineGoal(title: "Health")
        let child = RoutineGoal(title: "Run 5K", tags: ["Health", "Race"], parentGoalID: parent.id)
        context.insert(parent)
        context.insert(child)
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        let restoredGoals = try restoreContext.fetch(FetchDescriptor<RoutineGoal>())
        let restoredParent = try #require(restoredGoals.first { $0.id == parent.id })
        let restoredChild = try #require(restoredGoals.first { $0.id == child.id })

        #expect(summary.goals == 2)
        #expect(restoredParent.parentGoalID == nil)
        #expect(restoredChild.parentGoalID == parent.id)
        #expect(restoredChild.tags == ["Health", "Race"])
    }

    @Test
    func backupPackageAndRestore_preservesTaskImagesAndAttachments() async throws {
        let context = makeInMemoryContext()
        let imageData = Data([0x01, 0x02, 0x03])
        let attachmentData = Data([0x04, 0x05, 0x06])
        let task = RoutineTask(name: "File insurance", imageData: imageData)
        context.insert(task)
        context.insert(
            RoutineAttachment(
                taskID: task.id,
                fileName: "receipt.jpg",
                data: attachmentData
            )
        )
        try context.save()

        let packageURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        defer { try? FileManager.default.removeItem(at: packageURL) }

        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let restoreContext = makeInMemoryContext()
        let summary = try SettingsRoutineDataPersistence.replaceAllRoutineData(
            withBackupPackageAt: packageURL,
            in: restoreContext
        )

        #expect(summary.tasks == 1)
        #expect(summary.attachments == 1)
        let restoredTask = try #require(restoreContext.fetch(FetchDescriptor<RoutineTask>()).first)
        #expect(restoredTask.imageData == imageData)
        let restoredAttachment = try #require(restoreContext.fetch(FetchDescriptor<RoutineAttachment>()).first)
        #expect(restoredAttachment.taskID == restoredTask.id)
        #expect(restoredAttachment.fileName == "receipt.jpg")
        #expect(restoredAttachment.data == attachmentData)
    }
}
