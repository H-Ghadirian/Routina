import CloudKit
import Foundation
import SwiftData
import UserNotifications

enum CloudDataResetService {
    @MainActor
    static func resetAllUserData(
        cloudKitContainerIdentifier: String,
        modelContext: ModelContext
    ) async throws {
        try await deleteCloudRecordZones(containerIdentifier: cloudKitContainerIdentifier)
        try wipeLocalData(in: modelContext)
        clearLocalNotifications()
    }

    private static func deleteCloudRecordZones(containerIdentifier: String) async throws {
        let container = CKContainer(identifier: containerIdentifier)
        let database = container.privateCloudDatabase
        let zones = try await fetchAllRecordZones(from: database)
        let zoneIDsToDelete = zones.map(\.zoneID).filter(shouldDeleteZone)

        for zoneID in zoneIDsToDelete {
            try await deleteRecordZone(zoneID, from: database)
        }
    }

    private static func fetchAllRecordZones(
        from database: CKDatabase
    ) async throws -> [CKRecordZone] {
        try await withCheckedThrowingContinuation { continuation in
            database.fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: zones ?? [])
            }
        }
    }

    private static func deleteRecordZone(
        _ zoneID: CKRecordZone.ID,
        from database: CKDatabase
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            database.delete(withRecordZoneID: zoneID) { _, error in
                if let ckError = error as? CKError, ckError.code == .zoneNotFound {
                    continuation.resume(returning: ())
                    return
                }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private static func shouldDeleteZone(_ zoneID: CKRecordZone.ID) -> Bool {
        if zoneID.zoneName == CKRecordZone.default().zoneID.zoneName {
            return false
        }
        return !zoneID.zoneName.hasPrefix("_")
    }

    @MainActor
    private static func wipeLocalData(in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks {
            context.delete(task)
        }

        let logs = try context.fetch(FetchDescriptor<RoutineLog>())
        for log in logs {
            context.delete(log)
        }

        try context.save()
    }

    private static func clearLocalNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
