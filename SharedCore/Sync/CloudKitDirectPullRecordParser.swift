import CloudKit
import Foundation

enum CloudKitDirectPullRecordParser {
    typealias GoalPayload = CloudKitDirectPullService.GoalPayload
    typealias PlacePayload = CloudKitDirectPullService.PlacePayload
    typealias LogPayload = CloudKitDirectPullService.LogPayload

    static func parsePlace(from record: CKRecord) -> PlacePayload? {
        guard CloudKitDirectPullService.isPlaceRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let nameValue = CloudKitDirectPullService.stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        guard
            let latitudeValue = CloudKitDirectPullService.doubleValue(
                in: record,
                keys: ["latitude", "LATITUDE", "zlatitude", "ZLATITUDE", "cd_latitude"]
            ),
            let longitudeValue = CloudKitDirectPullService.doubleValue(
                in: record,
                keys: ["longitude", "LONGITUDE", "zlongitude", "ZLONGITUDE", "cd_longitude"]
            )
        else {
            return nil
        }

        let radiusValue = CloudKitDirectPullService.doubleValue(
            in: record,
            keys: ["radiusMeters", "RADIUSMETERS", "zradiusmeters", "ZRADIUSMETERS", "cd_radiusmeters"]
        ) ?? 150
        let createdAtValue = CloudKitDirectPullService.dateValue(
            in: record,
            keys: ["createdAt", "CREATEDAT", "zcreatedat", "ZCREATEDAT", "cd_createdat"]
        )

        return PlacePayload(
            id: id,
            name: nameValue,
            latitude: latitudeValue,
            longitude: longitudeValue,
            radiusMeters: radiusValue,
            createdAt: createdAtValue
        )
    }

    static func parseGoal(from record: CKRecord) -> GoalPayload? {
        guard CloudKitDirectPullService.isGoalRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let titleValue = CloudKitDirectPullService.stringValue(in: record, keys: ["title", "TITLE", "ztitle", "ZTITLE", "cd_title"])
        let emojiValue = CloudKitDirectPullService.stringValue(in: record, keys: ["emoji", "EMOJI", "zemoji", "ZEMOJI", "cd_emoji"])
        let notesValue = CloudKitDirectPullService.stringValue(in: record, keys: ["notes", "NOTES", "znotes", "ZNOTES", "cd_notes"])
        let targetDateValue = CloudKitDirectPullService.dateValue(
            in: record,
            keys: ["targetDate", "TARGETDATE", "ztargetdate", "ZTARGETDATE", "cd_targetdate"]
        )
        let statusValue = CloudKitDirectPullService.stringValue(
            in: record,
            keys: ["statusRawValue", "STATUSRAWVALUE", "zstatusrawvalue", "ZSTATUSRAWVALUE", "cd_statusrawvalue"]
        ).flatMap(RoutineGoalStatus.init(rawValue:))
        let colorValue = CloudKitDirectPullService.stringValue(
            in: record,
            keys: ["colorRawValue", "COLORRAWVALUE", "zcolorrawvalue", "ZCOLORRAWVALUE", "cd_colorrawvalue"]
        ).flatMap(RoutineTaskColor.init(rawValue:))
        let createdAtValue = CloudKitDirectPullService.dateValue(
            in: record,
            keys: ["createdAt", "CREATEDAT", "zcreatedat", "ZCREATEDAT", "cd_createdat"]
        )
        let sortOrderValue = CloudKitDirectPullService.intValue(
            in: record,
            keys: ["sortOrder", "SORTORDER", "zsortorder", "ZSORTORDER", "cd_sortorder"]
        )

        guard
            titleValue != nil
                || emojiValue != nil
                || notesValue != nil
                || targetDateValue != nil
                || statusValue != nil
                || colorValue != nil
                || createdAtValue != nil
                || sortOrderValue != nil
        else {
            return nil
        }

        return GoalPayload(
            id: id,
            title: titleValue,
            emoji: emojiValue,
            notes: notesValue,
            targetDate: targetDateValue,
            status: statusValue,
            color: colorValue,
            createdAt: createdAtValue,
            sortOrder: sortOrderValue
        )
    }

    static func parseLog(from record: CKRecord) -> LogPayload? {
        guard CloudKitDirectPullService.isLogRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        guard let taskID = CloudKitDirectPullService.uuidValue(
            in: record,
            keys: ["taskID", "taskId", "TASKID", "ztaskid", "ZTASKID", "cd_taskid"]
        ) else {
            return nil
        }

        let timestamp = CloudKitDirectPullService.dateValue(
            in: record,
            keys: ["timestamp", "TIMESTAMP", "ztimestamp", "ZTIMESTAMP", "cd_timestamp"]
        )
        let kindRawValue = CloudKitDirectPullService.stringValue(
            in: record,
            keys: ["kindRawValue", "kind", "KINDRAWVALUE", "zkindrawvalue", "ZKINDRAWVALUE", "cd_kindrawvalue"]
        )
        let actualDurationMinutes = CloudKitDirectPullService.intValue(
            in: record,
            keys: [
                "actualDurationMinutes",
                "ACTUALDURATIONMINUTES",
                "zactualdurationminutes",
                "ZACTUALDURATIONMINUTES",
                "cd_actualdurationminutes"
            ]
        )
        return LogPayload(
            id: id,
            timestamp: timestamp,
            taskID: taskID,
            kind: kindRawValue.flatMap(RoutineLogKind.init(rawValue:)) ?? .completed,
            actualDurationMinutes: RoutineLog.sanitizedActualDurationMinutes(actualDurationMinutes)
        )
    }
}
