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
struct SettingsRoutineDataBackupSafetyTests {
    @Test
    func verifiedExportCarriesPortableSourceReceipt() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Move safely")
        context.insert(task)
        context.insert(
            RoutineAttachment(
                taskID: task.id,
                fileName: "evidence.txt",
                data: Data("evidence".utf8)
            )
        )
        try context.save()

        let written = try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
            to: packageURL,
            from: context,
            verifiedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let checked = try SettingsRoutineDataBackupVerification.verifyForRestore(
            packageAt: packageURL
        )

        #expect(FileManager.default.fileExists(
            atPath: packageURL.appendingPathComponent(
                SettingsRoutineDataBackupVerification.receiptFileName
            ).path
        ))
        #expect(written.audit.semanticFingerprint == checked.audit.semanticFingerprint)
        #expect(checked.assurance.isSourceVerified)
        #expect(checked.audit.recordCounts["Tasks"] == 1)
        #expect(checked.audit.attachmentCount == 1)
    }

    @Test
    func changedAttachmentFailsPortableReceiptCheck() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        context.insert(
            RoutineTask(
                name: "Keep the image",
                imageData: Data([0x01, 0x02, 0x03])
            )
        )
        try context.save()
        _ = try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
            to: packageURL,
            from: context
        )

        let attachmentsURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.attachmentsDirectoryName,
            isDirectory: true
        )
        let attachmentURL = try #require(
            FileManager.default.contentsOfDirectory(
                at: attachmentsURL,
                includingPropertiesForKeys: nil
            ).first
        )
        try Data([0x09, 0x08, 0x07]).write(to: attachmentURL, options: .atomic)

        do {
            _ = try SettingsRoutineDataBackupVerification.verifyForRestore(
                packageAt: packageURL
            )
            Issue.record("Expected transferred attachment damage to fail verification.")
        } catch let error as SettingsRoutineDataBackupVerification.VerificationError {
            #expect(error == .semanticFingerprintMismatch)
        }
    }

    @Test
    func currentVerifiedSchemaCannotSilentlyLoseItsReceipt() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        context.insert(RoutineTask(name: "Receipt required"))
        try context.save()
        _ = try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
            to: packageURL,
            from: context
        )
        try FileManager.default.removeItem(
            at: packageURL.appendingPathComponent(
                SettingsRoutineDataBackupVerification.receiptFileName
            )
        )

        do {
            _ = try SettingsRoutineDataBackupVerification.verifyForRestore(
                packageAt: packageURL
            )
            Issue.record("Expected a current backup without its required receipt to fail.")
        } catch let error as SettingsRoutineDataBackupVerification.VerificationError {
            #expect(error == .missingRequiredReceipt)
        }
    }

    @Test
    func olderSupportedPackageWithoutReceiptRemainsRestorableAfterIsolation() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        context.insert(RoutineTask(name: "Older package"))
        try context.save()
        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: packageURL,
            from: context
        )

        let manifestURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.manifestFileName
        )
        var backup = try SettingsRoutineDataBackupCoding.decodeBackup(
            from: Data(contentsOf: manifestURL)
        )
        backup.schemaVersion = SettingsRoutineDataPersistence
            .verificationReceiptRequiredSchemaVersion - 1
        backup.verificationReceiptVersion = nil
        try SettingsRoutineDataBackupCoding.encode(backup).write(
            to: manifestURL,
            options: .atomic
        )

        let report = try SettingsRoutineDataBackupVerification.verifyForRestore(
            packageAt: packageURL
        )
        #expect(!report.assurance.isSourceVerified)
        #expect(!report.audit.comparedSourceDirectly)
    }

    @Test
    func comparisonDetectsBackupThatNoLongerMatchesLiveData() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        let task = RoutineTask(name: "Before change")
        context.insert(task)
        try context.save()
        _ = try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
            to: packageURL,
            from: context
        )

        task.name = "After change"
        try context.save()
        let result = try SettingsRoutineDataBackupVerification.compareWithLiveData(
            packageAt: packageURL,
            in: context
        )

        #expect(result.verification.assurance.isSourceVerified)
        #expect(!result.comparison.matchesLiveData)
        #expect(result.comparison.firstDifferencePath != nil)
    }

    @Test
    func failedLiveReplacementRollsBackOriginalData() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let sourceContext = makeInMemoryContext()
        sourceContext.insert(
            RoutineTask(
                name: "Broken candidate",
                imageData: Data([0x11, 0x12])
            )
        )
        try sourceContext.save()
        try SettingsRoutineDataPersistence.writeBackupPackage(
            to: packageURL,
            from: sourceContext
        )
        let attachmentsURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.attachmentsDirectoryName,
            isDirectory: true
        )
        let attachmentURL = try #require(
            FileManager.default.contentsOfDirectory(
                at: attachmentsURL,
                includingPropertiesForKeys: nil
            ).first
        )
        try FileManager.default.removeItem(at: attachmentURL)

        let liveContext = makeInMemoryContext()
        let originalTask = RoutineTask(name: "Original survives")
        liveContext.insert(originalTask)
        try liveContext.save()

        do {
            _ = try SettingsRoutineDataPersistence.replaceAllRoutineData(
                withBackupPackageAt: packageURL,
                in: liveContext
            )
            Issue.record("Expected the malformed restore to fail.")
        } catch {
            let remaining = try liveContext.fetch(FetchDescriptor<RoutineTask>())
            #expect(remaining.map(\.id) == [originalTask.id])
            #expect(remaining.first?.name == "Original survives")
        }
    }

    @Test
    func restoreCreatesVerifiedRecoveryPointBeforeReplacingLiveData() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let packageURL = rootURL
            .appendingPathComponent("candidate")
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
        let recoveryDirectoryURL = rootURL.appendingPathComponent("recovery", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let sourceContext = makeInMemoryContext()
        let restoredTask = RoutineTask(name: "Restored task")
        sourceContext.insert(restoredTask)
        try sourceContext.save()
        _ = try SettingsRoutineDataPersistence.writeVerifiedBackupPackage(
            to: packageURL,
            from: sourceContext
        )

        let liveContext = makeInMemoryContext()
        let previousTask = RoutineTask(name: "Previous task")
        liveContext.insert(previousTask)
        try liveContext.save()

        let result = try await SettingsRoutineDataTransferExecution.importData(
            from: packageURL,
            modelContext: { liveContext },
            appSettingsClient: { .noop },
            notificationClient: { .noop },
            recoveryDirectoryURL: { recoveryDirectoryURL }
        )

        #expect(result.verification.assurance.isSourceVerified)
        let liveTasks = try liveContext.fetch(FetchDescriptor<RoutineTask>())
        #expect(liveTasks.map(\.id) == [restoredTask.id])

        let recoveryPoint = try #require(result.recoveryPoint)
        let recoveryVerification = try SettingsRoutineDataBackupVerification.verifyForRestore(
            packageAt: recoveryPoint.packageURL
        )
        #expect(recoveryVerification.assurance.isSourceVerified)

        let recoveredContext = makeInMemoryContext()
        _ = try SettingsRoutineDataPersistence.replaceAllRoutineDataForAudit(
            withBackupPackageAt: recoveryPoint.packageURL,
            in: recoveredContext,
            importDate: recoveryPoint.createdAt
        )
        let recoveredTasks = try recoveredContext.fetch(FetchDescriptor<RoutineTask>())
        #expect(recoveredTasks.map(\.id) == [previousTask.id])
    }

    @Test
    func recoveryHistoryRetainsTenNewestVerifiedPoints() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let context = makeInMemoryContext()
        context.insert(RoutineTask(name: "Recovery history"))
        try context.save()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        for offset in 0..<11 {
            _ = try SettingsRoutineDataRecoveryStore.createPreRestoreRecoveryPoint(
                from: context,
                in: directoryURL,
                now: start.addingTimeInterval(TimeInterval(offset))
            )
        }

        let points = SettingsRoutineDataRecoveryStore.recoveryPoints(in: directoryURL)
        #expect(points.count == SettingsRoutineDataRecoveryStore.maximumRetainedRecoveryPoints)
        #expect(points.first?.createdAt == start.addingTimeInterval(10))
        #expect(points.last?.createdAt == start.addingTimeInterval(1))
    }

    @Test
    func recoveryRetentionPreservesThePointCurrentlyBeingRestored() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let context = makeInMemoryContext()
        context.insert(RoutineTask(name: "Preserve restore source"))
        try context.save()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        var oldestPoint: SettingsRoutineDataRecoveryPoint?
        for offset in 0..<SettingsRoutineDataRecoveryStore.maximumRetainedRecoveryPoints {
            let point = try SettingsRoutineDataRecoveryStore.createPreRestoreRecoveryPoint(
                from: context,
                in: directoryURL,
                now: start.addingTimeInterval(TimeInterval(offset))
            )
            if offset == 0 {
                oldestPoint = point
            }
        }

        let preserved = try #require(oldestPoint)
        _ = try SettingsRoutineDataRecoveryStore.createPreRestoreRecoveryPoint(
            from: context,
            in: directoryURL,
            preserving: preserved.packageURL,
            now: start.addingTimeInterval(10)
        )

        let points = SettingsRoutineDataRecoveryStore.recoveryPoints(in: directoryURL)
        #expect(points.count == SettingsRoutineDataRecoveryStore.maximumRetainedRecoveryPoints)
        #expect(points.contains(where: { $0.id == preserved.id }))
        #expect(!points.contains(where: {
            $0.createdAt == start.addingTimeInterval(1)
        }))
    }

    private func temporaryPackageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
    }
}
