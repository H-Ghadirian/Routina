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
        let rejectedTaskID = UUID()
        let child = RoutineGoal(
            title: "Run 5K",
            tags: ["Health", "Race"],
            parentGoalID: parent.id,
            rejectedTaskSuggestionIDs: [rejectedTaskID]
        )
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
        #expect(restoredChild.rejectedTaskSuggestionIDs == [rejectedTaskID])
    }

    @Test
    func backupPackageAndRestore_preservesTaskImagesVoiceNotesAndAttachments() async throws {
        let context = makeInMemoryContext()
        let imageData = Data([0x01, 0x02, 0x03])
        let voiceData = Data([0x07, 0x08, 0x09])
        let voiceCreatedAt = Date(timeIntervalSince1970: 250)
        let attachmentData = Data([0x04, 0x05, 0x06])
        let task = RoutineTask(
            name: "File insurance",
            imageData: imageData,
            voiceNoteData: voiceData,
            voiceNoteDurationSeconds: 3.5,
            voiceNoteCreatedAt: voiceCreatedAt
        )
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
        #expect(restoredTask.voiceNoteData == voiceData)
        #expect(restoredTask.voiceNoteDurationSeconds == 3.5)
        #expect(restoredTask.voiceNoteCreatedAt == voiceCreatedAt)
        let restoredAttachment = try #require(restoreContext.fetch(FetchDescriptor<RoutineAttachment>()).first)
        #expect(restoredAttachment.taskID == restoredTask.id)
        #expect(restoredAttachment.fileName == "receipt.jpg")
        #expect(restoredAttachment.data == attachmentData)
    }

    @Test
    func backupPackageAndRestore_preservesStandaloneNotesAndAttachments() async throws {
        let context = makeInMemoryContext()
        let imageData = Data([0x11, 0x12])
        let voiceData = Data([0x21, 0x22])
        let fileData = Data([0x31, 0x32])
        let createdAt = Date(timeIntervalSince1970: 300)
        let updatedAt = Date(timeIntervalSince1970: 360)
        let voiceCreatedAt = Date(timeIntervalSince1970: 330)
        let note = RoutineNote(
            title: "Visa paperwork",
            body: "Attach scanned permit forms",
            tags: ["Admin", "Visa"],
            imageData: imageData,
            voiceNoteData: voiceData,
            voiceNoteDurationSeconds: 4.25,
            voiceNoteCreatedAt: voiceCreatedAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        context.insert(note)
        context.insert(
            RoutineNoteAttachment(
                noteID: note.id,
                fileName: "permit.pdf",
                data: fileData,
                createdAt: createdAt
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

        #expect(summary.notes == 1)
        #expect(summary.attachments == 1)
        let restoredNote = try #require(restoreContext.fetch(FetchDescriptor<RoutineNote>()).first)
        #expect(restoredNote.title == "Visa paperwork")
        #expect(restoredNote.body == "Attach scanned permit forms")
        #expect(restoredNote.tags == ["Admin", "Visa"])
        #expect(restoredNote.imageData == imageData)
        #expect(restoredNote.voiceNoteData == voiceData)
        #expect(restoredNote.voiceNoteDurationSeconds == 4.25)
        #expect(restoredNote.voiceNoteCreatedAt == voiceCreatedAt)
        #expect(restoredNote.createdAt == createdAt)
        #expect(restoredNote.updatedAt == updatedAt)
        let restoredAttachment = try #require(restoreContext.fetch(FetchDescriptor<RoutineNoteAttachment>()).first)
        #expect(restoredAttachment.noteID == restoredNote.id)
        #expect(restoredAttachment.fileName == "permit.pdf")
        #expect(restoredAttachment.data == fileData)
    }
}
