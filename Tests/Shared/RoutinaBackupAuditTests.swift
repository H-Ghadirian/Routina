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
struct RoutinaBackupAuditTests {
    @Test
    func currentBackupPassesIsolatedSemanticRoundTripWithoutClearingLiveTokens() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        let goal = RoutineGoal(title: "Health")
        let task = RoutineTask(
            name: "Prepare appointment",
            imageData: Data([0x01, 0x02, 0x03]),
            tags: ["Health"]
        )
        task.goalIDs = [goal.id]
        context.insert(goal)
        context.insert(task)
        context.insert(
            RoutineLog(
                timestamp: Date(timeIntervalSince1970: 1_790_000_000),
                taskID: task.id,
                kind: .completed
            )
        )
        context.insert(
            RoutineAttachment(
                taskID: task.id,
                fileName: "appointment.txt",
                data: Data("bring records".utf8)
            )
        )
        context.insert(
            DayPlanBlockRecord(
                taskID: task.id,
                dayKey: "2026-08-29",
                startMinute: 9 * 60,
                durationMinutes: 45,
                titleSnapshot: "Prepare appointment"
            )
        )
        try context.save()
        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let tokenKey = "cloudKitDirectPull.serverChangeToken.audit-verification"
        let previousToken = UserDefaults.standard.object(forKey: tokenKey)
        let sentinel = Data([0xAA, 0xBB, 0xCC])
        UserDefaults.standard.set(sentinel, forKey: tokenKey)
        defer {
            if let previousToken {
                UserDefaults.standard.set(previousToken, forKey: tokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: tokenKey)
            }
        }

        let report = try RoutinaBackupAudit.audit(packageAt: packageURL)

        #expect(report.sourceSchemaVersion == SettingsRoutineDataPersistence.currentSchemaVersion)
        #expect(report.comparedSourceDirectly)
        #expect(report.recordCounts["Tasks"] == 1)
        #expect(report.recordCounts["Goals"] == 1)
        #expect(report.recordCounts["Logs"] == 1)
        #expect(report.recordCounts["Planner blocks"] == 1)
        #expect(report.attachmentCount == 2)
        #expect(report.attachmentBytes == 3 + Data("bring records".utf8).count)
        #expect(report.semanticFingerprint.count == 64)
        #expect(UserDefaults.standard.data(forKey: tokenKey) == sentinel)
    }

    @Test
    func auditRejectsMissingAttachmentBeforeRestore() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        context.insert(
            RoutineTask(
                name: "Task with image",
                imageData: Data([0x10, 0x20])
            )
        )
        try context.save()
        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

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

        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the missing attachment.")
        } catch let error as RoutinaBackupAudit.AuditError {
            guard case .missingAttachment = error else {
                Issue.record("Unexpected audit error: \(error)")
                return
            }
        }
    }

    @Test
    func auditRejectsUnsafeAttachmentFileName() throws {
        let packageURL = try makeImagePackage()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        var manifest = try loadManifest(from: packageURL)
        var attachments = try #require(manifest["attachments"] as? [[String: Any]])
        attachments[0]["fileName"] = "../outside.bin"
        manifest["attachments"] = attachments
        try writeManifest(manifest, to: packageURL)

        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the unsafe attachment name.")
        } catch let error as RoutinaBackupAudit.AuditError {
            #expect(error == .unsafeAttachmentFileName("../outside.bin"))
        }
    }

    @Test
    func auditRejectsDuplicateAttachmentIDAndFileName() throws {
        let packageURL = try makeImagePackage()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        var manifest = try loadManifest(from: packageURL)
        var attachments = try #require(manifest["attachments"] as? [[String: Any]])
        let duplicateID = try #require(attachments.first?["id"] as? String)
        attachments.append(attachments[0])
        manifest["attachments"] = attachments
        try writeManifest(manifest, to: packageURL)

        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the duplicate attachment.")
        } catch let error as RoutinaBackupAudit.AuditError {
            #expect(error == .duplicateAttachmentID(duplicateID))
        }

        attachments[1]["id"] = UUID().uuidString
        manifest["attachments"] = attachments
        try writeManifest(manifest, to: packageURL)

        let duplicateFileName = try #require(attachments.first?["fileName"] as? String)
        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the duplicate attachment file name.")
        } catch let error as RoutinaBackupAudit.AuditError {
            #expect(error == .duplicateAttachmentFileName(duplicateFileName))
        }
    }

    @Test
    func auditRejectsDanglingAttachmentReference() throws {
        let packageURL = try makeImagePackage()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        var manifest = try loadManifest(from: packageURL)
        let tasks = try #require(manifest["tasks"] as? [[String: Any]])
        let danglingID = try #require(tasks.first?["imageAttachmentID"] as? String)
        manifest["attachments"] = []
        try writeManifest(manifest, to: packageURL)

        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the dangling attachment reference.")
        } catch let error as RoutinaBackupAudit.AuditError {
            #expect(error == .danglingAttachmentReference(danglingID))
        }
    }

    @Test
    func auditRejectsSymbolicLinkAttachment() throws {
        let packageURL = try makeImagePackage()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let manifest = try loadManifest(from: packageURL)
        let attachments = try #require(manifest["attachments"] as? [[String: Any]])
        let fileName = try #require(attachments.first?["fileName"] as? String)
        let attachmentsURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.attachmentsDirectoryName,
            isDirectory: true
        )
        let attachmentURL = attachmentsURL.appendingPathComponent(fileName)
        let targetURL = attachmentsURL.appendingPathComponent("symlink-target.bin")
        try Data([0x01]).write(to: targetURL)
        try FileManager.default.removeItem(at: attachmentURL)
        try FileManager.default.createSymbolicLink(
            at: attachmentURL,
            withDestinationURL: targetURL
        )

        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the symbolic-link attachment.")
        } catch let error as RoutinaBackupAudit.AuditError {
            #expect(error == .invalidAttachmentFile(fileName))
        }
    }

    @Test
    func auditRejectsUnsupportedFutureSchema() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        context.insert(RoutineTask(name: "Future task"))
        try context.save()
        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)

        let manifestURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.manifestFileName
        )
        let manifestData = try Data(contentsOf: manifestURL)
        var manifest = try #require(
            JSONSerialization.jsonObject(with: manifestData) as? [String: Any]
        )
        let futureSchema = SettingsRoutineDataPersistence.currentSchemaVersion + 1
        manifest["schemaVersion"] = futureSchema
        try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: manifestURL, options: .atomic)

        do {
            _ = try RoutinaBackupAudit.audit(packageAt: packageURL)
            Issue.record("Expected the audit to reject the future schema.")
        } catch let error as RoutinaBackupAudit.AuditError {
            #expect(
                error == .unsupportedSchema(
                    found: futureSchema,
                    supported: 1...SettingsRoutineDataPersistence.currentSchemaVersion
                )
            )
        }
    }

    @Test
    func legacySchemaPackagePassesMigrationStabilityAudit() throws {
        let packageURL = temporaryPackageURL()
        defer { try? FileManager.default.removeItem(at: packageURL) }

        let context = makeInMemoryContext()
        context.insert(
            RoutineTask(
                name: "Legacy task",
                imageData: Data([0x31, 0x32, 0x33])
            )
        )
        try context.save()
        let exportedAt = Date(timeIntervalSince1970: 1_790_100_000)
        let legacyManifest = try SettingsRoutineDataPersistence.buildBackupJSON(
            from: context,
            exportedAt: exportedAt
        )

        try FileManager.default.createDirectory(
            at: packageURL.appendingPathComponent(
                SettingsRoutineDataPersistence.attachmentsDirectoryName,
                isDirectory: true
            ),
            withIntermediateDirectories: true
        )
        try legacyManifest.write(
            to: packageURL.appendingPathComponent(
                SettingsRoutineDataPersistence.manifestFileName
            ),
            options: .atomic
        )

        let report = try RoutinaBackupAudit.audit(packageAt: packageURL)

        #expect(report.sourceSchemaVersion == SettingsRoutineDataPersistence.legacyJSONSchemaVersion)
        #expect(!report.comparedSourceDirectly)
        #expect(report.recordCounts["Tasks"] == 1)
        #expect(report.semanticFingerprint.count == 64)
    }

    private func temporaryPackageURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(SettingsRoutineDataPersistence.backupPackageExtension)
    }

    private func makeImagePackage() throws -> URL {
        let packageURL = temporaryPackageURL()
        let context = makeInMemoryContext()
        context.insert(
            RoutineTask(
                name: "Task with image",
                imageData: Data([0x10, 0x20])
            )
        )
        try context.save()
        try SettingsRoutineDataPersistence.writeBackupPackage(to: packageURL, from: context)
        return packageURL
    }

    private func loadManifest(from packageURL: URL) throws -> [String: Any] {
        let manifestURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.manifestFileName
        )
        return try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL))
                as? [String: Any]
        )
    }

    private func writeManifest(
        _ manifest: [String: Any],
        to packageURL: URL
    ) throws {
        let manifestURL = packageURL.appendingPathComponent(
            SettingsRoutineDataPersistence.manifestFileName
        )
        try JSONSerialization.data(
            withJSONObject: manifest,
            options: [.prettyPrinted, .sortedKeys]
        ).write(to: manifestURL, options: .atomic)
    }
}
