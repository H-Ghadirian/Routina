import CloudKit
import Foundation
import SwiftData

enum CloudKitDirectPullService {
    private static let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: "__defaultOwner__"
    )

    struct PullResult {
        var changedRecords: [CKRecord]
        var deletedRecordIDs: [CKRecord.ID]
    }

    @MainActor
    static func pullLatestIntoLocalStore(
        containerIdentifier: String,
        modelContext: ModelContext
    ) async throws {
        let result = try await fetchZoneChanges(containerIdentifier: containerIdentifier)
        try merge(result: result, into: modelContext)
    }

    @MainActor
    static func mergeForTesting(
        _ result: PullResult,
        into context: ModelContext
    ) throws {
        try merge(result: result, into: context)
    }

    private static func fetchZoneChanges(containerIdentifier: String) async throws -> PullResult {
        let database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        var changedRecords: [CKRecord] = []
        var deletedRecordIDs: [CKRecord.ID] = []

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            func resumeIfNeeded(_ result: Result<PullResult, Error>) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(with: result)
            }

            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil
            config.desiredKeys = nil

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            operation.recordWasChangedBlock = { _, result in
                switch result {
                case .success(let record):
                    changedRecords.append(record)
                case .failure:
                    // Keep going; one failed record should not abort the whole pull.
                    break
                }
            }

            operation.recordWithIDWasDeletedBlock = { recordID, _ in
                deletedRecordIDs.append(recordID)
            }

            operation.recordZoneFetchResultBlock = { _, result in
                if case .failure(let error) = result {
                    resumeIfNeeded(.failure(error))
                }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    resumeIfNeeded(
                        .success(
                            PullResult(
                                changedRecords: changedRecords,
                                deletedRecordIDs: deletedRecordIDs
                            )
                        )
                    )
                case .failure(let error):
                    resumeIfNeeded(.failure(error))
                }
            }

            database.add(operation)
        }
    }

    @MainActor
    private static func merge(result: PullResult, into context: ModelContext) throws {
        var mergedPlaceIDs = try deduplicatePlaces(in: context)
        var mergedGoalIDs: [UUID: UUID] = [:]
        var mergedTaskIDs: [UUID: UUID] = [:]
        var placePayloads: [PlacePayload] = []
        var goalPayloads: [GoalPayload] = []
        var taskPayloads: [TaskPayload] = []
        var logPayloads: [LogPayload] = []

        for record in result.changedRecords {
            if let goalPayload = parseGoal(from: record) {
                goalPayloads.append(goalPayload)
                continue
            }

            if let placePayload = parsePlace(from: record) {
                placePayloads.append(placePayload)
                continue
            }

            if let taskPayload = parseTask(from: record) {
                taskPayloads.append(taskPayload)
                continue
            }

            if let logPayload = parseLog(from: record) {
                logPayloads.append(logPayload)
            }
        }

        for placePayload in placePayloads {
            mergedPlaceIDs[placePayload.id] = try upsertPlace(placePayload, in: context)
        }

        for goalPayload in goalPayloads {
            mergedGoalIDs[goalPayload.id] = try upsertGoal(goalPayload, in: context)
        }

        for taskPayload in taskPayloads {
            var canonicalPayload = taskPayload
            canonicalPayload.placeID = canonicalPayload.placeID.flatMap { placeID in
                canonicalPlaceID(for: placeID, mergedPlaceIDs: mergedPlaceIDs, in: context)
            }
            canonicalPayload.goalIDs = canonicalPayload.goalIDs?.map { goalID in
                canonicalGoalID(for: goalID, mergedGoalIDs: mergedGoalIDs, in: context)
            }
            mergedTaskIDs[taskPayload.id] = try upsertTask(canonicalPayload, in: context)
        }

        for logPayload in logPayloads {
            var canonicalPayload = logPayload
            canonicalPayload.taskID = mergedTaskIDs[logPayload.taskID]
                ?? canonicalTaskID(for: logPayload.taskID, in: context)
            try upsertLog(canonicalPayload, in: context)
        }

        for (sourcePlaceID, targetPlaceID) in mergedPlaceIDs where sourcePlaceID != targetPlaceID {
            try migratePlaceReferences(from: sourcePlaceID, to: targetPlaceID, in: context)
        }

        for (sourceTaskID, targetTaskID) in mergedTaskIDs where sourceTaskID != targetTaskID {
            try migrateLogs(from: sourceTaskID, to: targetTaskID, in: context)
        }

        for recordID in result.deletedRecordIDs {
            guard let id = UUID(uuidString: recordID.recordName) else { continue }
            if let targetTaskID = mergedTaskIDs[id], targetTaskID != id {
                continue
            }
            if let targetPlaceID = mergedPlaceIDs[id], targetPlaceID != id {
                continue
            }
            if let targetGoalID = mergedGoalIDs[id], targetGoalID != id {
                continue
            }

            let goalDescriptor = FetchDescriptor<RoutineGoal>(
                predicate: #Predicate { goal in
                    goal.id == id
                }
            )
            if let goal = try context.fetch(goalDescriptor).first {
                context.delete(goal)
                try clearGoalReference(goalID: id, in: context)
                continue
            }

            let placeDescriptor = FetchDescriptor<RoutinePlace>(
                predicate: #Predicate { place in
                    place.id == id
                }
            )
            if let place = try context.fetch(placeDescriptor).first {
                context.delete(place)
                try clearPlaceReference(placeID: id, in: context)
                continue
            }

            let taskDescriptor = FetchDescriptor<RoutineTask>(
                predicate: #Predicate { task in
                    task.id == id
                }
            )
            if let task = try context.fetch(taskDescriptor).first {
                context.delete(task)
            }

            let logDescriptor = FetchDescriptor<RoutineLog>(
                predicate: #Predicate { log in
                    log.id == id
                }
            )
            if let log = try context.fetch(logDescriptor).first {
                context.delete(log)
            }
        }

        try deduplicateLogs(in: context)

        if context.hasChanges {
            try context.save()
            NotificationCenter.default.postRoutineDidUpdate()
        }
    }

    private static func parsePlace(from record: CKRecord) -> PlacePayload? {
        guard isPlaceRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let nameValue = stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        guard
            let latitudeValue = doubleValue(in: record, keys: ["latitude", "LATITUDE", "zlatitude", "ZLATITUDE", "cd_latitude"]),
            let longitudeValue = doubleValue(in: record, keys: ["longitude", "LONGITUDE", "zlongitude", "ZLONGITUDE", "cd_longitude"])
        else {
            return nil
        }

        let radiusValue = doubleValue(
            in: record,
            keys: ["radiusMeters", "RADIUSMETERS", "zradiusmeters", "ZRADIUSMETERS", "cd_radiusmeters"]
        ) ?? 150
        let createdAtValue = dateValue(
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

    private static func parseGoal(from record: CKRecord) -> GoalPayload? {
        guard isGoalRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else { return nil }

        let titleValue = stringValue(in: record, keys: ["title", "TITLE", "ztitle", "ZTITLE", "cd_title"])
        let emojiValue = stringValue(in: record, keys: ["emoji", "EMOJI", "zemoji", "ZEMOJI", "cd_emoji"])
        let notesValue = stringValue(in: record, keys: ["notes", "NOTES", "znotes", "ZNOTES", "cd_notes"])
        let targetDateValue = dateValue(in: record, keys: ["targetDate", "TARGETDATE", "ztargetdate", "ZTARGETDATE", "cd_targetdate"])
        let statusValue = stringValue(
            in: record,
            keys: ["statusRawValue", "STATUSRAWVALUE", "zstatusrawvalue", "ZSTATUSRAWVALUE", "cd_statusrawvalue"]
        ).flatMap(RoutineGoalStatus.init(rawValue:))
        let colorValue = stringValue(
            in: record,
            keys: ["colorRawValue", "COLORRAWVALUE", "zcolorrawvalue", "ZCOLORRAWVALUE", "cd_colorrawvalue"]
        ).flatMap(RoutineTaskColor.init(rawValue:))
        let createdAtValue = dateValue(in: record, keys: ["createdAt", "CREATEDAT", "zcreatedat", "ZCREATEDAT", "cd_createdat"])
        let sortOrderValue = intValue(in: record, keys: ["sortOrder", "SORTORDER", "zsortorder", "ZSORTORDER", "cd_sortorder"])

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

    private static func parseTask(from record: CKRecord) -> TaskPayload? {
        guard isTaskRecordType(record.recordType) else { return nil }
        let id = UUID(uuidString: record.recordID.recordName)
        guard let id else { return nil }

        let intervalValue = intValue(in: record, keys: ["interval", "INTERVAL", "zinterval", "ZINTERVAL", "cd_interval"])
        let nameValue = stringValue(in: record, keys: ["name", "NAME", "zname", "ZNAME", "cd_name"])
        let emojiValue = stringValue(in: record, keys: ["emoji", "EMOJI", "zemoji", "ZEMOJI", "cd_emoji"])
        let notesValue = stringValue(in: record, keys: ["notes", "NOTES", "znotes", "ZNOTES", "cd_notes"])
        let linkValue = stringValue(in: record, keys: ["link", "LINK", "zlink", "ZLINK", "cd_link"])
        let deadlineValue = dateValue(in: record, keys: ["deadline", "DEADLINE", "zdeadline", "ZDEADLINE", "cd_deadline"])
        let reminderAtValue = dateValue(in: record, keys: ["reminderAt", "REMINDERAT", "zreminderat", "ZREMINDERAT", "cd_reminderat"])
        let placeIDValue = uuidValue(in: record, keys: ["placeID", "placeId", "PLACEID", "zplaceid", "ZPLACEID", "cd_placeid"])
        let tagsStorageValue = stringValue(in: record, keys: ["tagsStorage", "tagsstorage", "TAGSSTORAGE", "ztagsstorage", "ZTAGSSTORAGE", "cd_tagsstorage"])
        let goalIDsStorageValue = stringValue(
            in: record,
            keys: [
                "goalIDsStorage",
                "goalidsstorage",
                "GOALIDSSTORAGE",
                "zgoalidsstorage",
                "ZGOALIDSSTORAGE",
                "cd_goalidsstorage"
            ]
        )
        let stepsStorageValue = stringValue(in: record, keys: ["stepsStorage", "stepsstorage", "STEPSSTORAGE", "zstepsstorage", "ZSTEPSSTORAGE", "cd_stepsstorage"])
        let checklistItemsStorageValue = stringValue(
            in: record,
            keys: [
                "checklistItemsStorage",
                "checklistitemsstorage",
                "CHECKLISTITEMSSTORAGE",
                "zchecklistitemsstorage",
                "ZCHECKLISTITEMSSTORAGE",
                "cd_checklistitemsstorage"
            ]
        )
        let scheduleModeValue = stringValue(
            in: record,
            keys: [
                "scheduleModeRawValue",
                "schedulemoderawvalue",
                "SCHEDULEMODERAWVALUE",
                "zschedulemoderawvalue",
                "ZSCHEDULEMODERAWVALUE",
                "cd_schedulemoderawvalue"
            ]
        )
        let recurrenceRuleStorageValue = stringValue(
            in: record,
            keys: [
                "recurrenceRuleStorage",
                "recurrencerulestorage",
                "RECURRENCERULESTORAGE",
                "zrecurrencerulestorage",
                "ZRECURRENCERULESTORAGE",
                "cd_recurrencerulestorage"
            ]
        )
        let imageDataValue = dataValue(
            in: record,
            keys: ["imageData", "IMAGEDATA", "zimagedata", "ZIMAGEDATA", "cd_imagedata"]
        )
        let lastDoneValue = dateValue(in: record, keys: ["lastDone", "LASTDONE", "zlastdone", "ZLASTDONE", "cd_lastdone"])
        let canceledAtValue = dateValue(in: record, keys: ["canceledAt", "CANCELEDAT", "zcanceledat", "ZCANCELEDAT", "cd_canceledat"])
        let scheduleAnchorValue = dateValue(
            in: record,
            keys: ["scheduleAnchor", "SCHEDULEANCHOR", "zscheduleanchor", "ZSCHEDULEANCHOR", "cd_scheduleanchor"]
        )
        let pausedAtValue = dateValue(
            in: record,
            keys: ["pausedAt", "PAUSEDAT", "zpausedat", "ZPAUSEDAT", "cd_pausedat"]
        )
        let snoozedUntilValue = dateValue(
            in: record,
            keys: ["snoozedUntil", "SNOOZEDUNTIL", "zsnoozeduntil", "ZSNOOZEDUNTIL", "cd_snoozeduntil"]
        )
        let pinnedAtValue = dateValue(
            in: record,
            keys: ["pinnedAt", "PINNEDAT", "zpinnedat", "ZPINNEDAT", "cd_pinnedat"]
        )
        let completedStepCountValue = intValue(
            in: record,
            keys: ["completedStepCount", "COMPLETEDSTEPCOUNT", "zcompletedstepcount", "ZCOMPLETEDSTEPCOUNT", "cd_completedstepcount"]
        )
        let sequenceStartedAtValue = dateValue(
            in: record,
            keys: ["sequenceStartedAt", "SEQUENCESTARTEDAT", "zsequencestartedat", "ZSEQUENCESTARTEDAT", "cd_sequencestartedat"]
        )
        let createdAtValue = dateValue(
            in: record,
            keys: ["createdAt", "CREATEDAT", "zcreatedat", "ZCREATEDAT", "cd_createdat"]
        )
        let todoStateRawValueValue = stringValue(
            in: record,
            keys: ["todoStateRawValue", "TODOSTATERAWVALUE", "ztodostaterawvalue", "ZTODOSTATERAWVALUE", "cd_todostaterawvalue"]
        )
        let activityStateRawValueValue = stringValue(
            in: record,
            keys: ["activityStateRawValue", "ACTIVITYSTATERAWVALUE", "zactivitystaterawvalue", "ZACTIVITYSTATERAWVALUE", "cd_activitystaterawvalue"]
        )
        let ongoingSinceValue = dateValue(
            in: record,
            keys: ["ongoingSince", "ONGOINGSINCE", "zongoingsince", "ZONGOINGSINCE", "cd_ongoingsince"]
        )
        let autoAssumeDailyDoneValue = boolValue(
            in: record,
            keys: [
                "autoAssumeDailyDone",
                "AUTOASSUMEDAILYDONE",
                "zautoassumedailydone",
                "ZAUTOASSUMEDAILYDONE",
                "cd_autoassumedailydone"
            ]
        )
        let estimatedDurationMinutesValue = intValue(
            in: record,
            keys: [
                "estimatedDurationMinutes",
                "ESTIMATEDDURATIONMINUTES",
                "zestimateddurationminutes",
                "ZESTIMATEDDURATIONMINUTES",
                "cd_estimateddurationminutes"
            ]
        )
        let actualDurationMinutesValue = intValue(
            in: record,
            keys: [
                "actualDurationMinutes",
                "ACTUALDURATIONMINUTES",
                "zactualdurationminutes",
                "ZACTUALDURATIONMINUTES",
                "cd_actualdurationminutes"
            ]
        )
        let storyPointsValue = intValue(
            in: record,
            keys: [
                "storyPoints",
                "STORYPOINTS",
                "zstorypoints",
                "ZSTORYPOINTS",
                "cd_storypoints"
            ]
        )
        let pressureValue = stringValue(
            in: record,
            keys: ["pressureRawValue", "PRESSURERAWVALUE", "zpressurerawvalue", "ZPRESSURERAWVALUE", "cd_pressurerawvalue"]
        ).flatMap(RoutineTaskPressure.init(rawValue:))
        let pressureUpdatedAtValue = dateValue(
            in: record,
            keys: ["pressureUpdatedAt", "PRESSUREUPDATEDAT", "zpressureupdatedat", "ZPRESSUREUPDATEDAT", "cd_pressureupdatedat"]
        )

        guard
            intervalValue != nil
                || nameValue != nil
                || emojiValue != nil
                || notesValue != nil
                || linkValue != nil
                || deadlineValue != nil
                || placeIDValue != nil
                || tagsStorageValue != nil
                || goalIDsStorageValue != nil
                || stepsStorageValue != nil
                || checklistItemsStorageValue != nil
                || imageDataValue != nil
                || scheduleModeValue != nil
                || recurrenceRuleStorageValue != nil
                || lastDoneValue != nil
                || canceledAtValue != nil
                || scheduleAnchorValue != nil
                || pausedAtValue != nil
                || snoozedUntilValue != nil
                || pinnedAtValue != nil
                || completedStepCountValue != nil
                || sequenceStartedAtValue != nil
                || activityStateRawValueValue != nil
                || ongoingSinceValue != nil
                || pressureValue != nil
                || pressureUpdatedAtValue != nil
                || estimatedDurationMinutesValue != nil
                || actualDurationMinutesValue != nil
                || storyPointsValue != nil
                || autoAssumeDailyDoneValue != nil
        else {
            return nil
        }

        let stepsValue: [RoutineStep]?
        if let stepsStorageValue {
            let data = Data(stepsStorageValue.utf8)
            stepsValue = (try? JSONDecoder().decode([RoutineStep].self, from: data)).map(RoutineStep.sanitized)
        } else {
            stepsValue = nil
        }

        let checklistItemsValue: [RoutineChecklistItem]?
        if let checklistItemsStorageValue {
            let data = Data(checklistItemsStorageValue.utf8)
            checklistItemsValue = (try? JSONDecoder().decode([RoutineChecklistItem].self, from: data)).map(RoutineChecklistItem.sanitized)
        } else {
            checklistItemsValue = nil
        }

        return TaskPayload(
            id: id,
            name: nameValue,
            emoji: emojiValue,
            notes: notesValue,
            link: linkValue,
            deadline: deadlineValue,
            reminderAt: reminderAtValue,
            placeID: placeIDValue,
            tags: tagsStorageValue.map(RoutineTag.deserialize),
            goalIDs: goalIDsStorageValue.map(RoutineGoalIDStorage.deserialize),
            steps: stepsValue,
            checklistItems: checklistItemsValue,
            imageData: imageDataValue,
            scheduleMode: scheduleModeValue.flatMap(RoutineScheduleMode.init(rawValue:)),
            interval: Int16(clamping: intervalValue ?? 1),
            recurrenceRule: recurrenceRuleStorageValue.flatMap(RoutineRecurrenceRuleStorage.deserialize),
            lastDone: lastDoneValue,
            canceledAt: canceledAtValue,
            scheduleAnchor: scheduleAnchorValue,
            pausedAt: pausedAtValue,
            snoozedUntil: snoozedUntilValue,
            pinnedAt: pinnedAtValue,
            completedStepCount: Int16(clamping: completedStepCountValue ?? 0),
            sequenceStartedAt: sequenceStartedAtValue,
            createdAt: createdAtValue,
            todoStateRawValue: todoStateRawValueValue,
            activityStateRawValue: activityStateRawValueValue,
            ongoingSince: ongoingSinceValue,
            autoAssumeDailyDone: autoAssumeDailyDoneValue,
            estimatedDurationMinutes: estimatedDurationMinutesValue,
            actualDurationMinutes: RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutesValue),
            storyPoints: storyPointsValue,
            pressure: pressureValue,
            pressureUpdatedAt: pressureUpdatedAtValue
        )
    }

    private static func parseLog(from record: CKRecord) -> LogPayload? {
        guard isLogRecordType(record.recordType) else { return nil }
        guard let id = UUID(uuidString: record.recordID.recordName) else {
            return nil
        }

        guard let taskID = uuidValue(in: record, keys: ["taskID", "taskId", "TASKID", "ztaskid", "ZTASKID", "cd_taskid"]) else {
            return nil
        }

        let timestamp = dateValue(in: record, keys: ["timestamp", "TIMESTAMP", "ztimestamp", "ZTIMESTAMP", "cd_timestamp"])
        let kindRawValue = stringValue(in: record, keys: ["kindRawValue", "kind", "KINDRAWVALUE", "zkindrawvalue", "ZKINDRAWVALUE", "cd_kindrawvalue"])
        let actualDurationMinutes = intValue(
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

    @MainActor
    private static func upsertGoal(_ payload: GoalPayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == payloadID
            }
        )
        let normalizedIncomingTitle = RoutineGoal.normalizedTitle(payload.title)

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.createdAt ?? .distantPast }
        ) {
            update(existing, with: payload)
            return existing.id
        }

        if let normalizedIncomingTitle,
           let goalWithSameTitle = try goal(matchingNormalizedTitle: normalizedIncomingTitle, in: context) {
            update(goalWithSameTitle, with: payload)
            return goalWithSameTitle.id
        }

        context.insert(
            RoutineGoal(
                id: payload.id,
                title: RoutineGoal.cleanedTitle(payload.title) ?? "Goal",
                emoji: payload.emoji,
                notes: payload.notes,
                targetDate: payload.targetDate,
                status: payload.status ?? .active,
                color: payload.color ?? .none,
                createdAt: payload.createdAt ?? Date(),
                sortOrder: payload.sortOrder ?? 0
            )
        )
        return payload.id
    }

    private static func update(_ goal: RoutineGoal, with payload: GoalPayload) {
        goal.title = RoutineGoal.cleanedTitle(payload.title) ?? goal.displayTitle
        goal.emoji = RoutineGoal.cleanedEmoji(payload.emoji)
        goal.notes = payload.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        goal.targetDate = payload.targetDate
        if let status = payload.status {
            goal.status = status
        }
        if let color = payload.color {
            goal.color = color
        }
        if let createdAt = payload.createdAt {
            goal.createdAt = createdAt
        }
        if let sortOrder = payload.sortOrder {
            goal.sortOrder = sortOrder
        }
    }

    @MainActor
    private static func upsertPlace(_ payload: PlacePayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == payloadID
            }
        )
        let normalizedIncomingName = RoutinePlace.normalizedName(payload.name)

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.createdAt }
        ) {
            existing.name = RoutinePlace.cleanedName(payload.name) ?? existing.displayName
            existing.latitude = payload.latitude
            existing.longitude = payload.longitude
            existing.radiusMeters = max(payload.radiusMeters, 25)
            if let createdAt = payload.createdAt {
                existing.createdAt = createdAt
            }
            return existing.id
        }

        if let normalizedIncomingName,
           let placeWithSameName = try place(matchingNormalizedName: normalizedIncomingName, in: context) {
            placeWithSameName.latitude = payload.latitude
            placeWithSameName.longitude = payload.longitude
            placeWithSameName.radiusMeters = max(payload.radiusMeters, 25)
            if let createdAt = payload.createdAt {
                placeWithSameName.createdAt = createdAt
            }
            return placeWithSameName.id
        }

        context.insert(
            RoutinePlace(
                id: payload.id,
                name: RoutinePlace.cleanedName(payload.name) ?? "Place",
                latitude: payload.latitude,
                longitude: payload.longitude,
                radiusMeters: payload.radiusMeters,
                createdAt: payload.createdAt ?? Date()
            )
        )
        return payload.id
    }

    @MainActor
    private static func upsertTask(_ payload: TaskPayload, in context: ModelContext) throws -> UUID {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == payloadID
            }
        )
        let normalizedIncomingName = RoutineTask.normalizedName(payload.name)

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.lastDone ?? $0.createdAt ?? .distantPast }
        ) {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context),
               taskWithSameName.id != existing.id {
                // Keep local uniqueness invariant if cloud data contains a duplicate name.
                taskWithSameName.name = RoutineTask.trimmedName(payload.name)
                taskWithSameName.emoji = payload.emoji
                taskWithSameName.notes = RoutineTask.sanitizedNotes(payload.notes)
                taskWithSameName.link = RoutineTask.sanitizedLink(payload.link)
                taskWithSameName.imageData = payload.imageData
                taskWithSameName.placeID = payload.placeID
                if let tags = payload.tags {
                    taskWithSameName.tags = tags
                }
                if let goalIDs = payload.goalIDs {
                    taskWithSameName.goalIDs = goalIDs
                }
                if let steps = payload.steps {
                    taskWithSameName.replaceSteps(steps)
                }
                if let checklistItems = payload.checklistItems {
                    taskWithSameName.replaceChecklistItems(checklistItems)
                }
                if let scheduleMode = payload.scheduleMode {
                    taskWithSameName.scheduleMode = scheduleMode
                }
                taskWithSameName.deadline = taskWithSameName.scheduleMode == .oneOff ? payload.deadline : nil
                taskWithSameName.reminderAt = payload.reminderAt
                if let recurrenceRule = payload.recurrenceRule {
                    taskWithSameName.recurrenceRule = recurrenceRule
                } else {
                    taskWithSameName.interval = payload.interval
                }
                taskWithSameName.lastDone = payload.lastDone
                taskWithSameName.canceledAt = payload.canceledAt
                taskWithSameName.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? taskWithSameName.scheduleAnchor
                taskWithSameName.pausedAt = payload.pausedAt
                taskWithSameName.snoozedUntil = payload.snoozedUntil
                taskWithSameName.pinnedAt = payload.pinnedAt
                taskWithSameName.completedStepCount = payload.completedStepCount
                taskWithSameName.sequenceStartedAt = payload.sequenceStartedAt
                if let createdAt = payload.createdAt {
                    taskWithSameName.createdAt = createdAt
                }
                if let todoStateRawValue = payload.todoStateRawValue {
                    taskWithSameName.todoStateRawValue = todoStateRawValue
                }
                if let activityStateRawValue = payload.activityStateRawValue {
                    taskWithSameName.activityStateRawValue = activityStateRawValue
                }
                taskWithSameName.ongoingSince = payload.ongoingSince
                if let autoAssumeDailyDone = payload.autoAssumeDailyDone {
                    taskWithSameName.autoAssumeDailyDone = autoAssumeDailyDone
                }
                if let estimatedDurationMinutes = payload.estimatedDurationMinutes {
                    taskWithSameName.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
                }
                if let actualDurationMinutes = payload.actualDurationMinutes {
                    taskWithSameName.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutes)
                }
                if let storyPoints = payload.storyPoints {
                    taskWithSameName.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
                }
                if let pressure = payload.pressure {
                    taskWithSameName.pressure = pressure
                    taskWithSameName.pressureUpdatedAt = payload.pressureUpdatedAt
                }
                try migrateLogs(from: existing.id, to: taskWithSameName.id, in: context)
                return taskWithSameName.id
            }

            existing.name = RoutineTask.trimmedName(payload.name)
            existing.emoji = payload.emoji
            existing.notes = RoutineTask.sanitizedNotes(payload.notes)
            existing.link = RoutineTask.sanitizedLink(payload.link)
            existing.imageData = payload.imageData
            existing.placeID = payload.placeID
            if let tags = payload.tags {
                existing.tags = tags
            }
            if let goalIDs = payload.goalIDs {
                existing.goalIDs = goalIDs
            }
            if let steps = payload.steps {
                existing.replaceSteps(steps)
            }
            if let checklistItems = payload.checklistItems {
                existing.replaceChecklistItems(checklistItems)
            }
            if let scheduleMode = payload.scheduleMode {
                existing.scheduleMode = scheduleMode
            }
            existing.deadline = existing.scheduleMode == .oneOff ? payload.deadline : nil
            existing.reminderAt = payload.reminderAt
            if let recurrenceRule = payload.recurrenceRule {
                existing.recurrenceRule = recurrenceRule
            } else {
                existing.interval = payload.interval
            }
            existing.lastDone = payload.lastDone
            existing.canceledAt = payload.canceledAt
            existing.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? existing.scheduleAnchor
            existing.pausedAt = payload.pausedAt
            existing.snoozedUntil = payload.snoozedUntil
            existing.pinnedAt = payload.pinnedAt
            existing.completedStepCount = payload.completedStepCount
            existing.sequenceStartedAt = payload.sequenceStartedAt
            if let createdAt = payload.createdAt {
                existing.createdAt = createdAt
            }
            if let todoStateRawValue = payload.todoStateRawValue {
                existing.todoStateRawValue = todoStateRawValue
            }
            if let activityStateRawValue = payload.activityStateRawValue {
                existing.activityStateRawValue = activityStateRawValue
            }
            existing.ongoingSince = payload.ongoingSince
            if let autoAssumeDailyDone = payload.autoAssumeDailyDone {
                existing.autoAssumeDailyDone = autoAssumeDailyDone
            }
            if let estimatedDurationMinutes = payload.estimatedDurationMinutes {
                existing.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
            }
            if let actualDurationMinutes = payload.actualDurationMinutes {
                existing.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutes)
            }
            if let storyPoints = payload.storyPoints {
                existing.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
            }
            if let pressure = payload.pressure {
                existing.pressure = pressure
                existing.pressureUpdatedAt = payload.pressureUpdatedAt
            }
            return existing.id
        } else {
            if let normalizedIncomingName,
               let taskWithSameName = try task(matchingNormalizedName: normalizedIncomingName, in: context) {
                taskWithSameName.emoji = payload.emoji
                taskWithSameName.notes = RoutineTask.sanitizedNotes(payload.notes)
                taskWithSameName.link = RoutineTask.sanitizedLink(payload.link)
                taskWithSameName.imageData = payload.imageData
                taskWithSameName.placeID = payload.placeID
                if let tags = payload.tags {
                    taskWithSameName.tags = tags
                }
                if let goalIDs = payload.goalIDs {
                    taskWithSameName.goalIDs = goalIDs
                }
                if let steps = payload.steps {
                    taskWithSameName.replaceSteps(steps)
                }
                if let checklistItems = payload.checklistItems {
                    taskWithSameName.replaceChecklistItems(checklistItems)
                }
                if let scheduleMode = payload.scheduleMode {
                    taskWithSameName.scheduleMode = scheduleMode
                }
                taskWithSameName.deadline = taskWithSameName.scheduleMode == .oneOff ? payload.deadline : nil
                taskWithSameName.reminderAt = payload.reminderAt
                if let recurrenceRule = payload.recurrenceRule {
                    taskWithSameName.recurrenceRule = recurrenceRule
                } else {
                    taskWithSameName.interval = payload.interval
                }
                taskWithSameName.lastDone = payload.lastDone
                taskWithSameName.canceledAt = payload.canceledAt
                taskWithSameName.scheduleAnchor = payload.scheduleAnchor ?? payload.lastDone ?? taskWithSameName.scheduleAnchor
                taskWithSameName.pausedAt = payload.pausedAt
                taskWithSameName.snoozedUntil = payload.snoozedUntil
                taskWithSameName.pinnedAt = payload.pinnedAt
                taskWithSameName.completedStepCount = payload.completedStepCount
                taskWithSameName.sequenceStartedAt = payload.sequenceStartedAt
                if let createdAt = payload.createdAt {
                    taskWithSameName.createdAt = createdAt
                }
                if let todoStateRawValue = payload.todoStateRawValue {
                    taskWithSameName.todoStateRawValue = todoStateRawValue
                }
                if let activityStateRawValue = payload.activityStateRawValue {
                    taskWithSameName.activityStateRawValue = activityStateRawValue
                }
                taskWithSameName.ongoingSince = payload.ongoingSince
                if let autoAssumeDailyDone = payload.autoAssumeDailyDone {
                    taskWithSameName.autoAssumeDailyDone = autoAssumeDailyDone
                }
                if let estimatedDurationMinutes = payload.estimatedDurationMinutes {
                    taskWithSameName.estimatedDurationMinutes = RoutineTask.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
                }
                if let actualDurationMinutes = payload.actualDurationMinutes {
                    taskWithSameName.actualDurationMinutes = RoutineTask.sanitizedActualDurationMinutes(actualDurationMinutes)
                }
                if let storyPoints = payload.storyPoints {
                    taskWithSameName.storyPoints = RoutineTask.sanitizedStoryPoints(storyPoints)
                }
                if let pressure = payload.pressure {
                    taskWithSameName.pressure = pressure
                    taskWithSameName.pressureUpdatedAt = payload.pressureUpdatedAt
                }
                try migrateLogs(from: payload.id, to: taskWithSameName.id, in: context)
                return taskWithSameName.id
            }

            context.insert(
                RoutineTask(
                    id: payload.id,
                    name: RoutineTask.trimmedName(payload.name),
                    emoji: payload.emoji,
                    notes: payload.notes,
                    link: payload.link,
                    deadline: payload.deadline,
                    reminderAt: payload.reminderAt,
                    pressure: payload.pressure ?? .none,
                    pressureUpdatedAt: payload.pressureUpdatedAt,
                    imageData: payload.imageData,
                    placeID: payload.placeID,
                    tags: payload.tags ?? [],
                    goalIDs: payload.goalIDs ?? [],
                    steps: payload.steps ?? [],
                    checklistItems: payload.checklistItems ?? [],
                    scheduleMode: payload.scheduleMode,
                    interval: payload.interval,
                    recurrenceRule: payload.recurrenceRule,
                    lastDone: payload.lastDone,
                    canceledAt: payload.canceledAt,
                    scheduleAnchor: payload.scheduleAnchor,
                    pausedAt: payload.pausedAt,
                    snoozedUntil: payload.snoozedUntil,
                    pinnedAt: payload.pinnedAt,
                    completedStepCount: payload.completedStepCount,
                    sequenceStartedAt: payload.sequenceStartedAt,
                    createdAt: payload.createdAt,
                    todoStateRawValue: payload.todoStateRawValue,
                    activityStateRawValue: payload.activityStateRawValue,
                    ongoingSince: payload.ongoingSince,
                    autoAssumeDailyDone: payload.autoAssumeDailyDone ?? false,
                    estimatedDurationMinutes: payload.estimatedDurationMinutes,
                    actualDurationMinutes: payload.actualDurationMinutes,
                    storyPoints: payload.storyPoints
                )
            )
            return payload.id
        }
    }

    @MainActor
    private static func upsertLog(_ payload: LogPayload, in context: ModelContext) throws {
        let payloadID = payload.id
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.id == payloadID
            }
        )

        if let existing = try RoutineDuplicateIDCleanup.canonical(
            descriptor,
            in: context,
            rank: { $0.timestamp ?? .distantPast }
        ) {
            existing.timestamp = payload.timestamp
            existing.taskID = payload.taskID
            existing.kind = payload.kind
            existing.actualDurationMinutes = payload.actualDurationMinutes
        } else if let existing = try existingLog(matching: payload, in: context) {
            existing.timestamp = payload.timestamp
            existing.taskID = payload.taskID
            existing.kind = payload.kind
            existing.actualDurationMinutes = payload.actualDurationMinutes
        } else {
            context.insert(
                RoutineLog(
                    id: payload.id,
                    timestamp: payload.timestamp,
                    taskID: payload.taskID,
                    kind: payload.kind,
                    actualDurationMinutes: payload.actualDurationMinutes
                )
            )
        }
    }

    @MainActor
    private static func existingLog(
        matching payload: LogPayload,
        in context: ModelContext
    ) throws -> RoutineLog? {
        let taskID = payload.taskID
        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == taskID
            }
        )

        return try context.fetch(descriptor).first { log in
            timestampsMatch(log.timestamp, payload.timestamp)
        }
    }

    @MainActor
    private static func deduplicateLogs(in context: ModelContext) throws {
        let logs = try context.fetch(FetchDescriptor<RoutineLog>())

        var keptLogIDsByKey: [LogDeduplicationKey: UUID] = [:]
        for log in logs {
            let key = LogDeduplicationKey(taskID: log.taskID, timestamp: log.timestamp)
            if let keptLogID = keptLogIDsByKey[key], keptLogID != log.id {
                context.delete(log)
            } else {
                keptLogIDsByKey[key] = log.id
            }
        }
    }

    @MainActor
    private static func deduplicatePlaces(in context: ModelContext) throws -> [UUID: UUID] {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
        }

        var placesByNormalizedName: [String: [RoutinePlace]] = [:]
        var mergedPlaceIDs: [UUID: UUID] = [:]

        for place in places {
            guard let normalizedName = RoutinePlace.normalizedName(place.name) else { continue }
            placesByNormalizedName[normalizedName, default: []].append(place)
        }

        for sameNamedPlaces in placesByNormalizedName.values {
            guard sameNamedPlaces.count > 1 else { continue }

            let keeper = preferredPlaceToKeep(from: sameNamedPlaces, linkedCounts: linkedCounts)
            mergedPlaceIDs[keeper.id] = keeper.id
            for place in sameNamedPlaces where place.id != keeper.id {
                try migratePlaceReferences(from: place.id, to: keeper.id, in: context)
                context.delete(place)
                mergedPlaceIDs[place.id] = keeper.id
            }
        }

        return mergedPlaceIDs
    }

    @MainActor
    private static func migrateLogs(
        from sourceTaskID: UUID,
        to targetTaskID: UUID,
        in context: ModelContext
    ) throws {
        guard sourceTaskID != targetTaskID else { return }

        let descriptor = FetchDescriptor<RoutineLog>(
            predicate: #Predicate { log in
                log.taskID == sourceTaskID
            }
        )

        for log in try context.fetch(descriptor) {
            log.taskID = targetTaskID
        }
    }

    @MainActor
    private static func migratePlaceReferences(
        from sourcePlaceID: UUID,
        to targetPlaceID: UUID,
        in context: ModelContext
    ) throws {
        guard sourcePlaceID != targetPlaceID else { return }

        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeID == sourcePlaceID {
            task.placeID = targetPlaceID
        }
    }

    @MainActor
    private static func canonicalTaskID(for taskID: UUID, in context: ModelContext) -> UUID {
        let descriptor = FetchDescriptor<RoutineTask>(
            predicate: #Predicate { task in
                task.id == taskID
            }
        )
        let task = try? context.fetch(descriptor).first
        return task?.id ?? taskID
    }

    @MainActor
    private static func canonicalGoalID(
        for goalID: UUID,
        mergedGoalIDs: [UUID: UUID],
        in context: ModelContext
    ) -> UUID {
        var currentGoalID = goalID
        var visitedGoalIDs: Set<UUID> = []

        while let nextGoalID = mergedGoalIDs[currentGoalID], nextGoalID != currentGoalID {
            guard visitedGoalIDs.insert(currentGoalID).inserted else { break }
            currentGoalID = nextGoalID
        }

        let descriptor = FetchDescriptor<RoutineGoal>(
            predicate: #Predicate { goal in
                goal.id == currentGoalID
            }
        )
        let goal = try? context.fetch(descriptor).first
        return goal?.id ?? currentGoalID
    }

    @MainActor
    private static func canonicalPlaceID(
        for placeID: UUID,
        mergedPlaceIDs: [UUID: UUID],
        in context: ModelContext
    ) -> UUID {
        var currentPlaceID = placeID
        var visitedPlaceIDs: Set<UUID> = []

        while let nextPlaceID = mergedPlaceIDs[currentPlaceID], nextPlaceID != currentPlaceID {
            guard visitedPlaceIDs.insert(currentPlaceID).inserted else { break }
            currentPlaceID = nextPlaceID
        }

        let descriptor = FetchDescriptor<RoutinePlace>(
            predicate: #Predicate { place in
                place.id == currentPlaceID
            }
        )
        let place = try? context.fetch(descriptor).first
        return place?.id ?? currentPlaceID
    }

    private struct LogDeduplicationKey: Hashable {
        let taskID: UUID
        let timestampBucket: Int?

        init(taskID: UUID, timestamp: Date?) {
            self.taskID = taskID
            self.timestampBucket = timestamp.map { Int($0.timeIntervalSince1970.rounded()) }
        }
    }

    private static func timestampsMatch(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return abs(lhs.timeIntervalSince1970 - rhs.timeIntervalSince1970) < 1
        default:
            return false
        }
    }

    @MainActor
    private static func clearPlaceReference(placeID: UUID, in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.placeID == placeID {
            task.placeID = nil
        }
    }

    @MainActor
    private static func clearGoalReference(goalID: UUID, in context: ModelContext) throws {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        for task in tasks where task.goalIDs.contains(goalID) {
            task.goalIDs = task.goalIDs.filter { $0 != goalID }
        }
    }

    @MainActor
    private static func task(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutineTask? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        return tasks.first { task in
            RoutineTask.normalizedName(task.name) == normalizedName
        }
    }

    @MainActor
    private static func goal(
        matchingNormalizedTitle normalizedTitle: String,
        in context: ModelContext
    ) throws -> RoutineGoal? {
        let goals = try context.fetch(FetchDescriptor<RoutineGoal>())
        return goals.first { goal in
            RoutineGoal.normalizedTitle(goal.title) == normalizedTitle
        }
    }

    @MainActor
    private static func place(
        matchingNormalizedName normalizedName: String,
        in context: ModelContext
    ) throws -> RoutinePlace? {
        let tasks = try context.fetch(FetchDescriptor<RoutineTask>())
        let places = try context.fetch(FetchDescriptor<RoutinePlace>())
        let linkedCounts = tasks.reduce(into: [UUID: Int]()) { partialResult, task in
            guard let placeID = task.placeID else { return }
            partialResult[placeID, default: 0] += 1
        }

        let matchingPlaces = places.filter { place in
            RoutinePlace.normalizedName(place.name) == normalizedName
        }

        guard !matchingPlaces.isEmpty else { return nil }
        return preferredPlaceToKeep(from: matchingPlaces, linkedCounts: linkedCounts)
    }

    private static func preferredPlaceToKeep(
        from places: [RoutinePlace],
        linkedCounts: [UUID: Int]
    ) -> RoutinePlace {
        places.min { lhs, rhs in
            placeSelectionKey(lhs, linkedCounts: linkedCounts) < placeSelectionKey(rhs, linkedCounts: linkedCounts)
        } ?? places[0]
    }

    private static func placeSelectionKey(
        _ place: RoutinePlace,
        linkedCounts: [UUID: Int]
    ) -> (Int, Int, Date, String, String) {
        let rawName = place.name
        let trimmedName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedCountPenalty = -linkedCounts[place.id, default: 0]
        let whitespacePenalty = rawName == trimmedName ? 0 : 1
        let foldedName = trimmedName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return (
            linkedCountPenalty,
            whitespacePenalty,
            place.createdAt,
            foldedName,
            place.id.uuidString.lowercased()
        )
    }
}
