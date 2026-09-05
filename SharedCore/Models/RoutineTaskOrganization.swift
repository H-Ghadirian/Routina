import Foundation

extension RoutineTask {
    var customTaskSectionID: UUID? {
        get {
            guard let customTaskSectionIDRawValue else { return nil }
            return UUID(uuidString: customTaskSectionIDRawValue)
        }
        set {
            customTaskSectionIDRawValue = newValue?.uuidString.lowercased()
        }
    }

    var placeIDs: [UUID] {
        get {
            let storedPlaceIDs = RoutinePlaceIDStorage.deserialize(placeIDsStorage)
            if !storedPlaceIDs.isEmpty {
                return storedPlaceIDs
            }
            return placeID.map { [$0] } ?? []
        }
        set {
            let sanitizedPlaceIDs = RoutinePlaceIDStorage.sanitized(newValue)
            placeIDsStorage = RoutinePlaceIDStorage.serialize(sanitizedPlaceIDs)
            placeID = sanitizedPlaceIDs.first
        }
    }

    var steps: [RoutineStep] {
        get { RoutineStepStorage.deserialize(stepsStorage) }
        set {
            stepsStorage = RoutineStepStorage.serialize(newValue)
            if steps.isEmpty {
                resetStepProgress()
            } else if Int(completedStepCount) > steps.count {
                resetStepProgress()
            }
        }
    }

    var checklistItems: [RoutineChecklistItem] {
        get { RoutineChecklistItemStorage.deserialize(checklistItemsStorage) }
        set {
            checklistItemsStorage = RoutineChecklistItemStorage.serialize(
                RoutineChecklistItem.sanitized(newValue, for: scheduleMode)
            )
            sanitizeChecklistProgress()
        }
    }

    var completedChecklistItemIDs: Set<UUID> {
        get { RoutineChecklistProgressStorage.deserialize(completedChecklistItemIDsStorage) }
        set {
            completedChecklistItemIDsStorage = RoutineChecklistProgressStorage.serialize(newValue)
            if newValue.isEmpty {
                completedChecklistProgressStartedAt = nil
            }
        }
    }

    var manualSectionOrders: [String: Int] {
        get { RoutineSectionOrderStorage.deserialize(manualSectionOrderStorage) }
        set { manualSectionOrderStorage = RoutineSectionOrderStorage.serialize(newValue) }
    }

    func manualSectionOrder(for sectionKey: String) -> Int? {
        manualSectionOrders[sectionKey]
    }

    func setManualSectionOrder(_ order: Int, for sectionKey: String) {
        var updated = manualSectionOrders
        updated[sectionKey] = max(order, 0)
        manualSectionOrders = updated
    }

    var taskRankingOrders: [String: Int64] {
        get { TaskRankingOrderStorage.deserialize(taskRankingOrderStorage) }
        set { taskRankingOrderStorage = TaskRankingOrderStorage.serialize(newValue) }
    }

    var temporalWeightRule: RoutineTaskTemporalWeightRule? {
        get {
            RoutineTaskLadderConfigurationStorage.deserialize(
                temporalWeightRuleStorage
            ).temporalWeightRule
        }
        set {
            var configuration = RoutineTaskLadderConfigurationStorage.deserialize(
                temporalWeightRuleStorage
            )
            configuration.temporalWeightRule = newValue
            temporalWeightRuleStorage = RoutineTaskLadderConfigurationStorage.serialize(
                configuration
            )
        }
    }

    var taskLadderEntryWindow: RoutineTaskLadderEntryWindow {
        get {
            RoutineTaskLadderEntryWindow(
                storageLeadDays: RoutineTaskLadderConfigurationStorage.deserialize(
                    temporalWeightRuleStorage
                ).entryLeadDays
            )
        }
        set {
            var configuration = RoutineTaskLadderConfigurationStorage.deserialize(
                temporalWeightRuleStorage
            )
            configuration.entryLeadDays = newValue.storageLeadDays
            temporalWeightRuleStorage = RoutineTaskLadderConfigurationStorage.serialize(
                configuration
            )
        }
    }

    func taskRankingOrder(
        for metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        scopeTaskID: UUID? = nil
    ) -> Int64? {
        guard value.metric == metric else { return nil }
        return taskRankingOrders[
            TaskRankingOrderStorage.key(
                metric: metric,
                value: value,
                scopeTaskID: scopeTaskID
            )
        ]
    }

    func setTaskRankingOrder(
        _ order: Int64,
        for metric: TaskRankingMetric,
        value: TaskRankingMetricValue,
        scopeTaskID: UUID? = nil
    ) {
        guard value.metric == metric else { return }
        var updated = taskRankingOrders
        updated[
            TaskRankingOrderStorage.key(
                metric: metric,
                value: value,
                scopeTaskID: scopeTaskID
            )
        ] = order
        taskRankingOrders = updated
    }

    var relationships: [RoutineTaskRelationship] {
        get { RoutineTaskRelationshipStorage.deserialize(relationshipsStorage, ownerID: id) }
        set { relationshipsStorage = RoutineTaskRelationshipStorage.serialize(newValue, ownerID: id) }
    }

    var goalIDs: [UUID] {
        get { RoutineGoalIDStorage.deserialize(goalIDsStorage) }
        set { goalIDsStorage = RoutineGoalIDStorage.serialize(newValue) }
    }

    var eventIDs: [UUID] {
        get { RoutineEventIDStorage.deserialize(eventIDsStorage) }
        set { eventIDsStorage = RoutineEventIDStorage.serialize(newValue) }
    }

    var changeLogEntries: [RoutineTaskChangeLogEntry] {
        get {
            let entries = RoutineTaskChangeLogStorage.deserialize(changeLogStorage)
            if entries.isEmpty, let createdAt {
                return [RoutineTaskChangeLogEntry(timestamp: createdAt, kind: .created)]
            }
            return entries
        }
        set { changeLogStorage = RoutineTaskChangeLogStorage.serialize(newValue) }
    }

    var comments: [RoutineTaskComment] {
        get { RoutineTaskCommentStorage.deserialize(commentsStorage) }
        set { commentsStorage = RoutineTaskCommentStorage.serialize(newValue) }
    }
}
