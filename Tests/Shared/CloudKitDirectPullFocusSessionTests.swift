import CloudKit
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
struct CloudKitDirectPullFocusSessionTests {
    @Test
    func cloudKitMerge_marksAnExistingFocusSessionFinished() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Write", interval: 1, lastDone: nil, emoji: nil)
        let sessionID = UUID()
        let startedAt = makeDate("2026-08-08T08:00:00Z")
        let completedAt = makeDate("2026-08-08T09:00:00Z")
        let localSession = FocusSession(
            id: sessionID,
            taskID: task.id,
            startedAt: startedAt,
            plannedDurationSeconds: 60 * 60
        )
        context.insert(localSession)
        try context.save()

        let remoteSession = CKRecord(
            recordType: "FocusSession",
            recordID: CKRecord.ID(recordName: sessionID.uuidString)
        )
        remoteSession["taskID"] = task.id.uuidString as CKRecordValue
        remoteSession["startedAt"] = startedAt as CKRecordValue
        remoteSession["plannedDurationSeconds"] = NSNumber(value: 60 * 60)
        remoteSession["completedAt"] = completedAt as CKRecordValue

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [remoteSession], deletedRecordIDs: []),
            into: context
        )

        let session = try #require(
            try context.fetch(
                FetchDescriptor<FocusSession>(
                    predicate: #Predicate { session in
                        session.id == sessionID
                    }
                )
            ).first
        )
        #expect(session.completedAt == completedAt)
        #expect(session.state == .completed)
    }

    @Test
    func cloudKitMerge_doesNotReopenACompletedFocusSessionFromADelayedActiveRecord() throws {
        let context = makeInMemoryContext()
        let task = makeTask(in: context, name: "Read", interval: 1, lastDone: nil, emoji: nil)
        let sessionID = UUID()
        let startedAt = makeDate("2026-08-08T08:00:00Z")
        let completedAt = makeDate("2026-08-08T09:00:00Z")
        let localSession = FocusSession(
            id: sessionID,
            taskID: task.id,
            startedAt: startedAt,
            plannedDurationSeconds: 0,
            completedAt: completedAt
        )
        context.insert(localSession)
        try context.save()

        let delayedRemoteSession = CKRecord(
            recordType: "FocusSession",
            recordID: CKRecord.ID(recordName: sessionID.uuidString)
        )
        delayedRemoteSession["taskID"] = task.id.uuidString as CKRecordValue
        delayedRemoteSession["startedAt"] = startedAt as CKRecordValue
        delayedRemoteSession["plannedDurationSeconds"] = NSNumber(value: 0)

        try CloudKitDirectPullService.mergeForTesting(
            .init(changedRecords: [delayedRemoteSession], deletedRecordIDs: []),
            into: context
        )

        let session = try #require(
            try context.fetch(
                FetchDescriptor<FocusSession>(
                    predicate: #Predicate { session in
                        session.id == sessionID
                    }
                )
            ).first
        )
        #expect(session.completedAt == completedAt)
        #expect(session.state == .completed)
    }
}
