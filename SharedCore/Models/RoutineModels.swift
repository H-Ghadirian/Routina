import Foundation
import SwiftData

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var notes: String?
    var link: String?
    var deadline: Date?
    var reminderAt: Date?
    var priorityRawValue: String = RoutineTaskPriority.none.rawValue
    var importanceRawValue: String = RoutineTaskImportance.level2.rawValue
    var urgencyRawValue: String = RoutineTaskUrgency.level2.rawValue
    var pressureRawValue: String = RoutineTaskPressure.none.rawValue
    var pressureUpdatedAt: Date?
    @Attribute(.externalStorage) var imageData: Data?
    var placeID: UUID?
    var tagsStorage: String = ""
    var stepsStorage: String = ""
    var checklistItemsStorage: String = ""
    var completedChecklistItemIDsStorage: String = ""
    var relationshipsStorage: String = ""
    var goalIDsStorage: String = ""
    var scheduleModeRawValue: String = RoutineScheduleMode.fixedInterval.rawValue
    var recurrenceRuleStorage: String = ""
    var interval: Int16 = 1
    var lastDone: Date?
    var canceledAt: Date?
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var snoozedUntil: Date?
    var pinnedAt: Date?
    var manualSectionOrderStorage: String = ""
    var completedStepCount: Int16 = 0
    var sequenceStartedAt: Date?
    var colorRawValue: String = RoutineTaskColor.none.rawValue
    var createdAt: Date? = nil
    var todoStateRawValue: String? = nil
    var activityStateRawValue: String = RoutineActivityState.idle.rawValue
    var ongoingSince: Date?
    var autoAssumeDailyDone: Bool = false
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled: Bool = false
    var changeLogStorage: String = ""

    var hasNotes: Bool {
        RoutineTask.sanitizedNotes(notes) != nil
    }

    var hasImage: Bool {
        imageData?.isEmpty == false
    }

    var priority: RoutineTaskPriority {
        get { RoutineTaskPriority(rawValue: priorityRawValue) ?? .none }
        set { priorityRawValue = newValue.rawValue }
    }

    var importance: RoutineTaskImportance {
        get { RoutineTaskImportance(rawValue: importanceRawValue) ?? .level2 }
        set { importanceRawValue = newValue.rawValue }
    }

    var urgency: RoutineTaskUrgency {
        get { RoutineTaskUrgency(rawValue: urgencyRawValue) ?? .level2 }
        set { urgencyRawValue = newValue.rawValue }
    }

    var pressure: RoutineTaskPressure {
        get { RoutineTaskPressure(rawValue: pressureRawValue) ?? .none }
        set {
            pressureRawValue = newValue.rawValue
            pressureUpdatedAt = newValue == .none ? nil : Date()
        }
    }

    var color: RoutineTaskColor {
        get { RoutineTaskColor(rawValue: colorRawValue) ?? .none }
        set { colorRawValue = newValue.rawValue }
    }

    var importanceUrgencyLabel: String {
        "\(importance.title) • \(urgency.title)"
    }

    var derivedPriorityFromMatrix: RoutineTaskPriority {
        let score = importance.sortOrder + urgency.sortOrder
        switch score {
        case ..<4:
            return .low
        case 4:
            return .medium
        case 5...6:
            return .high
        default:
            return .urgent
        }
    }

    var tags: [String] {
        get { RoutineTag.deserialize(tagsStorage) }
        set { tagsStorage = RoutineTag.serialize(newValue) }
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
            checklistItemsStorage = RoutineChecklistItemStorage.serialize(newValue)
            sanitizeChecklistProgress()
        }
    }

    var completedChecklistItemIDs: Set<UUID> {
        get { RoutineChecklistProgressStorage.deserialize(completedChecklistItemIDsStorage) }
        set { completedChecklistItemIDsStorage = RoutineChecklistProgressStorage.serialize(newValue) }
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

    var relationships: [RoutineTaskRelationship] {
        get { RoutineTaskRelationshipStorage.deserialize(relationshipsStorage, ownerID: id) }
        set { relationshipsStorage = RoutineTaskRelationshipStorage.serialize(newValue, ownerID: id) }
    }

    var goalIDs: [UUID] {
        get { RoutineGoalIDStorage.deserialize(goalIDsStorage) }
        set { goalIDsStorage = RoutineGoalIDStorage.serialize(newValue) }
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

    var scheduleMode: RoutineScheduleMode {
        get { RoutineScheduleMode(rawValue: scheduleModeRawValue) ?? .fixedInterval }
        set {
            scheduleModeRawValue = newValue.rawValue
            if newValue == .oneOff {
                checklistItemsStorage = ""
                completedChecklistItemIDsStorage = ""
            } else {
                deadline = nil
            }
            sanitizeChecklistProgress()
        }
    }

    var recurrenceRule: RoutineRecurrenceRule {
        get {
            RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage)
                ?? .interval(days: max(Int(interval), 1))
        }
        set {
            recurrenceRuleStorage = RoutineRecurrenceRuleStorage.serialize(newValue)
            interval = Int16(clamping: scheduleMode == .oneOff ? 1 : newValue.approximateIntervalDays)
        }
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        emoji: String? = nil,
        notes: String? = nil,
        link: String? = nil,
        deadline: Date? = nil,
        reminderAt: Date? = nil,
        priority: RoutineTaskPriority = .none,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        pressure: RoutineTaskPressure = .none,
        pressureUpdatedAt: Date? = nil,
        imageData: Data? = nil,
        placeID: UUID? = nil,
        tags: [String] = [],
        goalIDs: [UUID] = [],
        relationships: [RoutineTaskRelationship] = [],
        steps: [RoutineStep] = [],
        checklistItems: [RoutineChecklistItem] = [],
        scheduleMode: RoutineScheduleMode? = nil,
        interval: Int16 = 1,
        recurrenceRule: RoutineRecurrenceRule? = nil,
        lastDone: Date? = nil,
        canceledAt: Date? = nil,
        scheduleAnchor: Date? = nil,
        pausedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        pinnedAt: Date? = nil,
        completedStepCount: Int16 = 0,
        sequenceStartedAt: Date? = nil,
        color: RoutineTaskColor = .none,
        createdAt: Date? = Date(),
        todoStateRawValue: String? = nil,
        activityStateRawValue: String? = nil,
        ongoingSince: Date? = nil,
        autoAssumeDailyDone: Bool = false,
        estimatedDurationMinutes: Int? = nil,
        actualDurationMinutes: Int? = nil,
        storyPoints: Int? = nil,
        focusModeEnabled: Bool = false
    ) {
        let resolvedScheduleMode = scheduleMode ?? (checklistItems.isEmpty ? .fixedInterval : .derivedFromChecklist)
        let resolvedChecklistItems = resolvedScheduleMode == .oneOff ? [] : checklistItems
        let resolvedRecurrenceRule = resolvedScheduleMode == .oneOff
            ? RoutineRecurrenceRule.interval(days: 1)
            : recurrenceRule ?? RoutineRecurrenceRule.interval(days: max(Int(interval), 1))
        self.id = id
        self.name = name
        self.emoji = emoji
        self.notes = Self.sanitizedNotes(notes)
        self.link = Self.sanitizedLink(link)
        self.deadline = resolvedScheduleMode == .oneOff ? deadline : nil
        self.reminderAt = reminderAt
        self.priorityRawValue = priority.rawValue
        self.importanceRawValue = importance.rawValue
        self.urgencyRawValue = urgency.rawValue
        self.pressureRawValue = pressure.rawValue
        self.pressureUpdatedAt = pressure == .none ? nil : pressureUpdatedAt
        self.imageData = imageData
        self.placeID = placeID
        self.tagsStorage = RoutineTag.serialize(tags)
        self.goalIDsStorage = RoutineGoalIDStorage.serialize(goalIDs)
        self.relationshipsStorage = RoutineTaskRelationshipStorage.serialize(relationships, ownerID: id)
        self.stepsStorage = RoutineStepStorage.serialize(steps)
        self.checklistItemsStorage = RoutineChecklistItemStorage.serialize(resolvedChecklistItems)
        self.scheduleModeRawValue = resolvedScheduleMode.rawValue
        self.recurrenceRuleStorage = RoutineRecurrenceRuleStorage.serialize(resolvedRecurrenceRule)
        self.interval = Int16(clamping: resolvedScheduleMode == .oneOff ? 1 : resolvedRecurrenceRule.approximateIntervalDays)
        self.lastDone = lastDone
        self.canceledAt = resolvedScheduleMode == .oneOff ? canceledAt : nil
        self.scheduleAnchor = resolvedScheduleMode == .oneOff ? lastDone : (scheduleAnchor ?? lastDone)
        self.pausedAt = pausedAt
        self.snoozedUntil = snoozedUntil
        self.pinnedAt = pinnedAt
        self.manualSectionOrderStorage = ""
        self.completedStepCount = Int16(max(Int(completedStepCount), 0))
        self.sequenceStartedAt = sequenceStartedAt
        self.colorRawValue = color.rawValue
        self.createdAt = createdAt
        self.todoStateRawValue = todoStateRawValue
        self.activityStateRawValue = RoutineActivityState(rawValue: activityStateRawValue ?? "")?.rawValue ?? RoutineActivityState.idle.rawValue
        self.ongoingSince = ongoingSince
        self.autoAssumeDailyDone = autoAssumeDailyDone
        self.estimatedDurationMinutes = Self.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
        self.actualDurationMinutes = Self.sanitizedActualDurationMinutes(actualDurationMinutes)
        self.storyPoints = Self.sanitizedStoryPoints(storyPoints)
        self.focusModeEnabled = focusModeEnabled
        var initialChanges = [
            RoutineTaskChangeLogEntry(
                timestamp: createdAt ?? Date(),
                kind: .created
            )
        ]
        initialChanges.append(
            contentsOf: RoutineTaskRelationship.sanitized(relationships, ownerID: id).map {
                RoutineTaskChangeLogEntry(
                    timestamp: createdAt ?? Date(),
                    kind: .linkedTaskAdded,
                    relatedTaskID: $0.targetTaskID,
                    relationshipKind: $0.kind
                )
            }
        )
        self.changeLogStorage = RoutineTaskChangeLogStorage.serialize(initialChanges)
        if self.steps.isEmpty || Int(self.completedStepCount) > self.steps.count {
            resetStepProgress()
        }
        sanitizeChecklistProgress()
    }

    func replaceRelationships(_ updatedRelationships: [RoutineTaskRelationship]) {
        relationshipsStorage = RoutineTaskRelationshipStorage.serialize(updatedRelationships, ownerID: id)
    }

    static func trimmedName(_ name: String?) -> String? {
        RoutineModelValueSanitizer.trimmedName(name)
    }

    static func normalizedName(_ name: String?) -> String? {
        RoutineModelValueSanitizer.normalizedName(name)
    }

    static func sanitizedNotes(_ notes: String?) -> String? {
        RoutineModelValueSanitizer.sanitizedNotes(notes)
    }

    static func sanitizedLink(_ link: String?) -> String? {
        RoutineModelValueSanitizer.sanitizedLink(link)
    }

    var resolvedLinkURL: URL? {
        Self.sanitizedLink(link).flatMap(URL.init(string:))
    }

    static func sanitizedEmoji(_ input: String, fallback: String) -> String {
        RoutineModelValueSanitizer.sanitizedEmoji(input, fallback: fallback)
    }

    static func resolvedRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskResolvedRelationship] {
        RoutineTaskRelationshipResolution.resolvedRelationships(for: task, within: candidates)
    }

    static func removeRelationships(
        targeting deletedTaskIDs: Set<UUID>,
        from tasks: [RoutineTask]
    ) {
        RoutineTaskRelationshipResolution.removeRelationships(targeting: deletedTaskIDs, from: tasks)
    }

    func detachedCopy() -> RoutineTask {
        let copy = RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            notes: notes,
            link: link,
            deadline: deadline,
            reminderAt: reminderAt,
            priority: priority,
            importance: importance,
            urgency: urgency,
            pressure: pressure,
            pressureUpdatedAt: pressureUpdatedAt,
            imageData: imageData,
            placeID: placeID,
            tags: tags,
            goalIDs: goalIDs,
            relationships: relationships,
            steps: steps,
            checklistItems: checklistItems,
            scheduleMode: scheduleMode,
            interval: interval,
            recurrenceRule: recurrenceRule,
            lastDone: lastDone,
            canceledAt: canceledAt,
            scheduleAnchor: scheduleAnchor,
            pausedAt: pausedAt,
            snoozedUntil: snoozedUntil,
            pinnedAt: pinnedAt,
            completedStepCount: completedStepCount,
            sequenceStartedAt: sequenceStartedAt,
            color: color,
            createdAt: createdAt,
            todoStateRawValue: todoStateRawValue,
            activityStateRawValue: activityStateRawValue,
            ongoingSince: ongoingSince,
            autoAssumeDailyDone: autoAssumeDailyDone,
            estimatedDurationMinutes: estimatedDurationMinutes,
            actualDurationMinutes: actualDurationMinutes,
            storyPoints: storyPoints,
            focusModeEnabled: focusModeEnabled
        )
        copy.completedChecklistItemIDsStorage = completedChecklistItemIDsStorage
        copy.manualSectionOrderStorage = manualSectionOrderStorage
        copy.changeLogStorage = changeLogStorage
        copy.scheduleAnchor = scheduleAnchor
        return copy
    }

    func appendChangeLogEntry(_ entry: RoutineTaskChangeLogEntry) {
        changeLogEntries = [entry] + changeLogEntries
    }

    static func sanitizedEstimatedDurationMinutes(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }

    static func sanitizedActualDurationMinutes(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }

    static func sanitizedStoryPoints(_ value: Int?) -> Int? {
        RoutineModelValueSanitizer.sanitizedPositiveInteger(value)
    }
}

extension RoutineTask: Equatable {
    static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.id == rhs.id
    }
}
