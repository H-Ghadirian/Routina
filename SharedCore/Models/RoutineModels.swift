import Foundation
import SwiftData

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var notes: String?
    var link: String?
    var linksStorage: String = ""
    var deadline: Date?
    var plannedDate: Date?
    var isAllDay: Bool = false
    var routineDurationModeRawValue: String = RoutineDurationMode.oneDay.rawValue
    var availabilityStartDate: Date?
    var availabilityEndDate: Date?
    var reminderAt: Date?
    var priorityRawValue: String = RoutineTaskPriority.none.rawValue
    var importanceRawValue: String = RoutineTaskImportance.level2.rawValue
    var urgencyRawValue: String = RoutineTaskUrgency.level2.rawValue
    var pressureRawValue: String = RoutineTaskPressure.none.rawValue
    var pressureUpdatedAt: Date?
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var voiceNoteData: Data?
    var voiceNoteDurationSeconds: Double?
    var voiceNoteCreatedAt: Date?
    var placeID: UUID?
    var placeIDsStorage: String = ""
    var tagsStorage: String = ""
    var stepsStorage: String = ""
    var checklistItemsStorage: String = ""
    var completedChecklistItemIDsStorage: String = ""
    var completedChecklistProgressStartedAt: Date?
    var relationshipsStorage: String = ""
    var goalIDsStorage: String = ""
    var eventIDsStorage: String = ""
    var scheduleModeRawValue: String = RoutineScheduleMode.fixedInterval.rawValue
    var recurrenceStorageVersion: Int16 = 0
    var recurrenceKindRawValue: String = RoutineRecurrenceRule.Kind.intervalDays.rawValue
    var recurrenceTimeOfDayHour: Int?
    var recurrenceTimeOfDayMinute: Int?
    var recurrenceTimeRangeStartHour: Int?
    var recurrenceTimeRangeStartMinute: Int?
    var recurrenceTimeRangeEndHour: Int?
    var recurrenceTimeRangeEndMinute: Int?
    var recurrenceTimeRangeRoleRawValue: String = RoutineTimeRangeRole.availability.rawValue
    var recurrenceWeekday: Int?
    var recurrenceDayOfMonth: Int?
    // Legacy JSON storage retained only so existing stores can be backfilled into the typed recurrence columns.
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
    var autoAssumeDoneTimeOfDayHour: Int?
    var autoAssumeDoneTimeOfDayMinute: Int?
    var estimatedDurationMinutes: Int?
    var actualDurationMinutes: Int?
    var storyPoints: Int?
    var focusModeEnabled: Bool = false
    var commentsStorage: String = ""
    var changeLogStorage: String = ""

    var hasNotes: Bool {
        RoutineTask.sanitizedNotes(notes) != nil
    }

    var hasImage: Bool {
        imageData?.isEmpty == false
    }

    var hasVoiceNote: Bool {
        voiceNoteData?.isEmpty == false
    }

    var voiceNote: RoutineVoiceNote? {
        get {
            RoutineVoiceNote(
                data: voiceNoteData,
                durationSeconds: voiceNoteDurationSeconds,
                createdAt: voiceNoteCreatedAt
            )
        }
        set {
            voiceNoteData = newValue?.data
            voiceNoteDurationSeconds = newValue?.durationSeconds
            voiceNoteCreatedAt = newValue?.createdAt
        }
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

    var autoAssumeDoneTimeOfDay: RoutineTimeOfDay? {
        get {
            guard let hour = autoAssumeDoneTimeOfDayHour,
                  let minute = autoAssumeDoneTimeOfDayMinute
            else { return nil }
            return RoutineTimeOfDay(hour: hour, minute: minute)
        }
        set {
            autoAssumeDoneTimeOfDayHour = newValue?.hour
            autoAssumeDoneTimeOfDayMinute = newValue?.minute
        }
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

    var links: [String] {
        get {
            linkItems.map(\.url)
        }
        set {
            let sanitizedLinks = Self.sanitizedLinks(newValue)
            linksStorage = RoutineTaskLinkStorage.serialize(sanitizedLinks)
            link = sanitizedLinks.first
        }
    }

    var linkItems: [RoutineTaskLink] {
        get {
            let storedLinks = RoutineTaskLinkStorage.deserializeItems(linksStorage)
            if !storedLinks.isEmpty {
                return storedLinks
            }
            return Self.sanitizedLink(link).map { [RoutineTaskLink(title: nil, url: $0)] } ?? []
        }
        set {
            let sanitizedLinks = RoutineTaskLinkStorage.sanitizedItems(newValue)
            linksStorage = RoutineTaskLinkStorage.serializeItems(sanitizedLinks)
            link = sanitizedLinks.first?.url
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

    var scheduleMode: RoutineScheduleMode {
        get { RoutineScheduleMode(rawValue: scheduleModeRawValue) ?? .fixedInterval }
        set {
            scheduleModeRawValue = newValue.rawValue
            if newValue != .oneOff {
                deadline = nil
                availabilityStartDate = nil
                availabilityEndDate = nil
            }
            if newValue.taskType == .record {
                plannedDate = nil
            }
            if newValue.taskType == .todo {
                routineDurationMode = .oneDay
            }
            if hasChecklistItems {
                checklistItemsStorage = RoutineChecklistItemStorage.serialize(
                    RoutineChecklistItem.sanitized(checklistItems, for: newValue)
                )
            }
            sanitizeChecklistProgress()
        }
    }

    var routineDurationMode: RoutineDurationMode {
        get {
            guard scheduleMode.taskType != .todo else { return .oneDay }
            return RoutineDurationMode(rawValue: routineDurationModeRawValue) ?? .oneDay
        }
        set {
            routineDurationModeRawValue = scheduleMode.taskType == .todo
                ? RoutineDurationMode.oneDay.rawValue
                : newValue.rawValue
        }
    }

    var isMultiDayRoutine: Bool {
        scheduleMode.taskType != .todo && routineDurationMode == .multiDay
    }

    var usesOngoingLifecycle: Bool {
        isSoftIntervalRoutine || isMultiDayRoutine
    }

    var recurrenceRule: RoutineRecurrenceRule {
        get {
            if let storedRule = RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage),
               storedRule.hasMultipleCalendarSelections {
                return storedRule
            }
            if recurrenceStorageVersion >= Self.currentRecurrenceStorageVersion {
                return recurrenceRuleFromColumns
            }
            return RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage)
                ?? recurrenceRuleFromColumns
        }
        set {
            let normalizedRule: RoutineRecurrenceRule
            switch scheduleMode.taskType {
            case .routine:
                normalizedRule = newValue
            case .todo:
                normalizedRule = RoutineRecurrenceRule.interval(
                    days: 1,
                    at: newValue.timeOfDay,
                    timeRange: newValue.timeRange
                )
            case .record:
                normalizedRule = RoutineRecurrenceRule.interval(
                    days: 1,
                    at: newValue.timeOfDay,
                    timeRange: newValue.timeRange
                )
            }
            storeRecurrenceRuleInColumns(normalizedRule)
            if normalizedRule.timeRange == nil {
                recurrenceTimeRangeRole = .availability
            }
        }
    }

    var recurrenceTimeRangeRole: RoutineTimeRangeRole {
        get { RoutineTimeRangeRole(rawValue: recurrenceTimeRangeRoleRawValue) ?? .availability }
        set { recurrenceTimeRangeRoleRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        emoji: String? = nil,
        notes: String? = nil,
        link: String? = nil,
        links: [String] = [],
        deadline: Date? = nil,
        plannedDate: Date? = nil,
        isAllDay: Bool = false,
        routineDurationMode: RoutineDurationMode = .oneDay,
        availabilityStartDate: Date? = nil,
        availabilityEndDate: Date? = nil,
        reminderAt: Date? = nil,
        priority: RoutineTaskPriority = .none,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        pressure: RoutineTaskPressure = .none,
        pressureUpdatedAt: Date? = nil,
        imageData: Data? = nil,
        voiceNoteData: Data? = nil,
        voiceNoteDurationSeconds: Double? = nil,
        voiceNoteCreatedAt: Date? = nil,
        placeID: UUID? = nil,
        placeIDs: [UUID] = [],
        tags: [String] = [],
        goalIDs: [UUID] = [],
        eventIDs: [UUID] = [],
        relationships: [RoutineTaskRelationship] = [],
        steps: [RoutineStep] = [],
        checklistItems: [RoutineChecklistItem] = [],
        scheduleMode: RoutineScheduleMode? = nil,
        interval: Int16 = 1,
        recurrenceRule: RoutineRecurrenceRule? = nil,
        recurrenceTimeRangeRole: RoutineTimeRangeRole = .availability,
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
        autoAssumeDoneTimeOfDay: RoutineTimeOfDay? = nil,
        estimatedDurationMinutes: Int? = nil,
        actualDurationMinutes: Int? = nil,
        storyPoints: Int? = nil,
        focusModeEnabled: Bool = false,
        comments: [RoutineTaskComment] = []
    ) {
        let resolvedScheduleMode = scheduleMode ?? (checklistItems.isEmpty ? .fixedInterval : .derivedFromChecklist)
        let resolvedChecklistItems = checklistItems
        let inputRecurrenceRule = recurrenceRule ?? RoutineRecurrenceRule.interval(days: max(Int(interval), 1))
        let resolvedRecurrenceRule: RoutineRecurrenceRule
        switch resolvedScheduleMode.taskType {
        case .routine:
            resolvedRecurrenceRule = inputRecurrenceRule
        case .todo:
            resolvedRecurrenceRule = RoutineRecurrenceRule.interval(
                days: 1,
                at: inputRecurrenceRule.timeOfDay,
                timeRange: inputRecurrenceRule.timeRange
            )
        case .record:
            resolvedRecurrenceRule = RoutineRecurrenceRule.interval(
                days: 1,
                at: inputRecurrenceRule.timeOfDay,
                timeRange: inputRecurrenceRule.timeRange
            )
        }
        self.id = id
        self.name = name
        self.emoji = emoji
        self.notes = Self.sanitizedNotes(notes)
        let sanitizedLinks = RoutineTaskLinkStorage.sanitizedItems(links.isEmpty
            ? link.map { [RoutineTaskLink(title: nil, url: $0)] } ?? []
            : links.map { RoutineTaskLink(title: nil, url: $0) }
        )
        self.link = sanitizedLinks.first?.url
        self.linksStorage = RoutineTaskLinkStorage.serializeItems(sanitizedLinks)
        self.deadline = resolvedScheduleMode == .oneOff ? deadline : nil
        self.plannedDate = resolvedScheduleMode.taskType == .record
            ? nil
            : Self.normalizedPlannedDate(plannedDate)
        self.isAllDay = isAllDay
        self.routineDurationModeRawValue = resolvedScheduleMode.taskType == .todo
            ? RoutineDurationMode.oneDay.rawValue
            : routineDurationMode.rawValue
        self.availabilityStartDate = resolvedScheduleMode == .oneOff ? availabilityStartDate : nil
        self.availabilityEndDate = resolvedScheduleMode == .oneOff ? availabilityEndDate : nil
        self.reminderAt = resolvedScheduleMode.taskType == .record ? nil : reminderAt
        self.priorityRawValue = priority.rawValue
        self.importanceRawValue = importance.rawValue
        self.urgencyRawValue = urgency.rawValue
        self.pressureRawValue = pressure.rawValue
        self.pressureUpdatedAt = pressure == .none ? nil : pressureUpdatedAt
        self.imageData = imageData
        let sanitizedVoiceNote = RoutineVoiceNote(
            data: voiceNoteData,
            durationSeconds: voiceNoteDurationSeconds,
            createdAt: voiceNoteCreatedAt
        )
        self.voiceNoteData = sanitizedVoiceNote?.data
        self.voiceNoteDurationSeconds = sanitizedVoiceNote?.durationSeconds
        self.voiceNoteCreatedAt = sanitizedVoiceNote?.createdAt
        let resolvedPlaceIDs = RoutinePlaceIDStorage.sanitized(placeIDs.isEmpty ? placeID.map { [$0] } ?? [] : placeIDs)
        self.placeID = resolvedPlaceIDs.first
        self.placeIDsStorage = RoutinePlaceIDStorage.serialize(resolvedPlaceIDs)
        self.tagsStorage = RoutineTag.serialize(tags)
        self.goalIDsStorage = RoutineGoalIDStorage.serialize(goalIDs)
        self.eventIDsStorage = RoutineEventIDStorage.serialize(eventIDs)
        self.relationshipsStorage = RoutineTaskRelationshipStorage.serialize(relationships, ownerID: id)
        self.stepsStorage = RoutineStepStorage.serialize(steps)
        self.scheduleModeRawValue = resolvedScheduleMode.rawValue
        self.checklistItemsStorage = RoutineChecklistItemStorage.serialize(
            RoutineChecklistItem.sanitized(resolvedChecklistItems, for: resolvedScheduleMode)
        )
        storeRecurrenceRuleInColumns(resolvedRecurrenceRule)
        self.recurrenceTimeRangeRole = resolvedRecurrenceRule.timeRange == nil
            ? .availability
            : recurrenceTimeRangeRole
        self.interval = Int16(clamping: resolvedScheduleMode.taskType == .routine ? resolvedRecurrenceRule.approximateIntervalDays : 1)
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
        self.autoAssumeDoneTimeOfDay = autoAssumeDailyDone ? autoAssumeDoneTimeOfDay : nil
        self.estimatedDurationMinutes = Self.sanitizedEstimatedDurationMinutes(estimatedDurationMinutes)
        self.actualDurationMinutes = Self.sanitizedActualDurationMinutes(actualDurationMinutes)
        self.storyPoints = Self.sanitizedStoryPoints(storyPoints)
        self.focusModeEnabled = focusModeEnabled
        self.commentsStorage = RoutineTaskCommentStorage.serialize(comments)
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

    @discardableResult
    func migrateLegacyRecurrenceRuleStorageIfNeeded() -> Bool {
        guard recurrenceStorageVersion < Self.currentRecurrenceStorageVersion else { return false }
        let legacyRule = RoutineRecurrenceRuleStorage.deserialize(recurrenceRuleStorage)
            ?? .interval(days: max(Int(interval), 1))
        storeRecurrenceRuleInColumns(legacyRule)
        return true
    }

    private static var currentRecurrenceStorageVersion: Int16 { 1 }

    private var recurrenceRuleFromColumns: RoutineRecurrenceRule {
        let kind = RoutineRecurrenceRule.Kind(rawValue: recurrenceKindRawValue) ?? .intervalDays
        let exactTime = recurrenceTimeOfDay
        let timeRange = recurrenceTimeRange

        switch kind {
        case .intervalDays:
            return .interval(
                days: max(Int(interval), 1),
                at: exactTime,
                timeRange: timeRange
            )
        case .dailyTime:
            return RoutineRecurrenceRule(
                kind: .dailyTime,
                timeOfDay: exactTime,
                timeRange: timeRange
            )
        case .weekly:
            return .weekly(
                on: recurrenceWeekday ?? Calendar.current.firstWeekday,
                at: exactTime,
                timeRange: timeRange
            )
        case .monthlyDay:
            return .monthly(
                on: recurrenceDayOfMonth ?? Calendar.current.component(.day, from: Date()),
                at: exactTime,
                timeRange: timeRange
            )
        }
    }

    private var recurrenceTimeOfDay: RoutineTimeOfDay? {
        guard let hour = recurrenceTimeOfDayHour,
              let minute = recurrenceTimeOfDayMinute else {
            return nil
        }
        return RoutineTimeOfDay(hour: hour, minute: minute)
    }

    private var recurrenceTimeRange: RoutineTimeRange? {
        guard let startHour = recurrenceTimeRangeStartHour,
              let startMinute = recurrenceTimeRangeStartMinute,
              let endHour = recurrenceTimeRangeEndHour,
              let endMinute = recurrenceTimeRangeEndMinute else {
            return nil
        }
        return RoutineTimeRange(
            start: RoutineTimeOfDay(hour: startHour, minute: startMinute),
            end: RoutineTimeOfDay(hour: endHour, minute: endMinute)
        )
    }

    private func storeRecurrenceRuleInColumns(_ recurrenceRule: RoutineRecurrenceRule) {
        recurrenceStorageVersion = Self.currentRecurrenceStorageVersion
        recurrenceKindRawValue = recurrenceRule.kind.rawValue
        interval = Int16(clamping: scheduleMode.taskType == .routine ? recurrenceRule.approximateIntervalDays : 1)
        recurrenceTimeOfDayHour = recurrenceRule.timeOfDay?.hour
        recurrenceTimeOfDayMinute = recurrenceRule.timeOfDay?.minute
        recurrenceTimeRangeStartHour = recurrenceRule.timeRange?.start.hour
        recurrenceTimeRangeStartMinute = recurrenceRule.timeRange?.start.minute
        recurrenceTimeRangeEndHour = recurrenceRule.timeRange?.end.hour
        recurrenceTimeRangeEndMinute = recurrenceRule.timeRange?.end.minute
        recurrenceWeekday = recurrenceRule.weekday
        recurrenceDayOfMonth = recurrenceRule.dayOfMonth
        recurrenceRuleStorage = recurrenceRule.hasMultipleCalendarSelections
            ? RoutineRecurrenceRuleStorage.serialize(recurrenceRule)
            : ""
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

    static func sanitizedLinks(_ links: [String]) -> [String] {
        RoutineTaskLinkStorage.sanitized(links)
    }

    static func sanitizedLinks(fromEditorText text: String) -> [String] {
        sanitizedLinkItems(fromEditorText: text).map(\.url)
    }

    static func linkEditorText(for links: [String]) -> String {
        linkEditorText(for: links.map { RoutineTaskLink(title: nil, url: $0) })
    }

    static func sanitizedLinkItems(fromEditorText text: String) -> [RoutineTaskLink] {
        let items = text.components(separatedBy: .newlines).map { line in
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 2 {
                return RoutineTaskLink(title: parts[0], url: parts.dropFirst().joined(separator: "\t"))
            }
            return RoutineTaskLink(title: nil, url: line)
        }
        return RoutineTaskLinkStorage.sanitizedItems(items)
    }

    static func linkEditorText(for links: [RoutineTaskLink]) -> String {
        RoutineTaskLinkStorage.sanitizedItems(links)
            .map { link in
                if let title = link.title, !title.isEmpty {
                    return "\(title)\t\(link.url)"
                }
                return link.url
            }
            .joined(separator: "\n")
    }

    static func normalizedAvailabilityDateBounds(
        startDate: Date?,
        endDate: Date?,
        calendar: Calendar = .current
    ) -> (startDate: Date?, endDate: Date?) {
        guard let startDate else {
            return (nil, nil)
        }
        let normalizedStartDate = calendar.startOfDay(for: startDate)
        guard let endDate else {
            return (normalizedStartDate, nil)
        }
        let normalizedEndDate = calendar.startOfDay(for: endDate)
        return (
            normalizedStartDate,
            normalizedEndDate < normalizedStartDate ? normalizedStartDate : normalizedEndDate
        )
    }

    static func normalizedPlannedDate(
        _ plannedDate: Date?,
        calendar: Calendar = .current
    ) -> Date? {
        plannedDate.map { calendar.startOfDay(for: $0) }
    }

    var resolvedLinkURL: URL? {
        resolvedLinkURLs.first?.url
    }

    var resolvedLinkURLs: [RoutineTaskResolvedLink] {
        linkItems.compactMap { link in
            guard let url = URL(string: link.url) else { return nil }
            return RoutineTaskResolvedLink(text: link.displayText, url: url)
        }
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

    static func editableRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskRelationship] {
        RoutineTaskRelationshipResolution.editableRelationships(for: task, within: candidates)
    }

    static func removeRelationships(
        targeting deletedTaskIDs: Set<UUID>,
        from tasks: [RoutineTask]
    ) {
        RoutineTaskRelationshipResolution.removeRelationships(targeting: deletedTaskIDs, from: tasks)
    }

    static func removeInverseRelationships(
        targeting ownerID: UUID,
        from tasks: [RoutineTask]
    ) {
        RoutineTaskRelationshipResolution.removeInverseRelationships(targeting: ownerID, from: tasks)
    }

    func detachedCopy() -> RoutineTask {
        let copy = RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            notes: notes,
            link: link,
            links: links,
            deadline: deadline,
            plannedDate: plannedDate,
            isAllDay: isAllDay,
            routineDurationMode: routineDurationMode,
            availabilityStartDate: availabilityStartDate,
            availabilityEndDate: availabilityEndDate,
            reminderAt: reminderAt,
            priority: priority,
            importance: importance,
            urgency: urgency,
            pressure: pressure,
            pressureUpdatedAt: pressureUpdatedAt,
            imageData: imageData,
            voiceNoteData: voiceNoteData,
            voiceNoteDurationSeconds: voiceNoteDurationSeconds,
            voiceNoteCreatedAt: voiceNoteCreatedAt,
            placeID: placeID,
            placeIDs: placeIDs,
            tags: tags,
            goalIDs: goalIDs,
            eventIDs: eventIDs,
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
            autoAssumeDoneTimeOfDay: autoAssumeDoneTimeOfDay,
            estimatedDurationMinutes: estimatedDurationMinutes,
            actualDurationMinutes: actualDurationMinutes,
            storyPoints: storyPoints,
            focusModeEnabled: focusModeEnabled,
            comments: comments
        )
        copy.completedChecklistItemIDsStorage = completedChecklistItemIDsStorage
        copy.completedChecklistProgressStartedAt = completedChecklistProgressStartedAt
        copy.manualSectionOrderStorage = manualSectionOrderStorage
        copy.linkItems = linkItems
        copy.commentsStorage = commentsStorage
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
