import CloudKit
import Foundation

struct CloudKitDirectPullPayloadBatch {
    var placePayloads: [CloudKitDirectPullService.PlacePayload] = []
    var goalPayloads: [CloudKitDirectPullService.GoalPayload] = []
    var taskPayloads: [CloudKitDirectPullService.TaskPayload] = []
    var logPayloads: [CloudKitDirectPullService.LogPayload] = []

    static func make(from records: [CKRecord]) -> CloudKitDirectPullPayloadBatch {
        var batch = CloudKitDirectPullPayloadBatch()

        for record in records {
            if let goalPayload = CloudKitDirectPullRecordParser.parseGoal(from: record) {
                batch.goalPayloads.append(goalPayload)
                continue
            }

            if let placePayload = CloudKitDirectPullRecordParser.parsePlace(from: record) {
                batch.placePayloads.append(placePayload)
                continue
            }

            if let taskPayload = CloudKitDirectPullTaskRecordParser.parse(from: record) {
                batch.taskPayloads.append(taskPayload)
                continue
            }

            if let logPayload = CloudKitDirectPullRecordParser.parseLog(from: record) {
                batch.logPayloads.append(logPayload)
            }
        }

        return batch
    }
}
