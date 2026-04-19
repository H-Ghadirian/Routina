import Foundation
import SwiftData

private enum RoutineStepStorage {
    static func serialize(_ steps: [RoutineStep]) -> String {
        let sanitized = RoutineStep.sanitized(steps)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineStep] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineStep].self, from: data) else {
            return []
        }
        return RoutineStep.sanitized(decoded)
    }
}

private enum RoutineChecklistItemStorage {
    static func serialize(_ items: [RoutineChecklistItem]) -> String {
        let sanitized = RoutineChecklistItem.sanitized(items)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [RoutineChecklistItem] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineChecklistItem].self, from: data) else {
            return []
        }
        return RoutineChecklistItem.sanitized(decoded)
    }
}

private enum RoutineChecklistProgressStorage {
    static func serialize(_ itemIDs: Set<UUID>) -> String {
        let sorted = itemIDs.sorted { $0.uuidString < $1.uuidString }
        guard !sorted.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sorted),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> Set<UUID> {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([UUID].self, from: data) else {
            return []
        }
        return Set(decoded)
    }
}

private enum RoutineTaskRelationshipStorage {
    static func serialize(_ relationships: [RoutineTaskRelationship], ownerID: UUID? = nil) -> String {
        let sanitized = RoutineTaskRelationship.sanitized(relationships, ownerID: ownerID)
        guard !sanitized.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(sanitized),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String, ownerID: UUID? = nil) -> [RoutineTaskRelationship] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([RoutineTaskRelationship].self, from: data) else {
            return []
        }
        return RoutineTaskRelationship.sanitized(decoded, ownerID: ownerID)
    }
}

private enum RoutineSectionOrderStorage {
    static func serialize(_ orders: [String: Int]) -> String {
        guard !orders.isEmpty else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(orders),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> [String: Int] {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else {
            return [:]
        }
        return decoded
    }
}

enum RoutineRecurrenceRuleStorage {
    static func serialize(_ recurrenceRule: RoutineRecurrenceRule) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(recurrenceRule),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func deserialize(_ storage: String) -> RoutineRecurrenceRule? {
        guard !storage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = storage.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(RoutineRecurrenceRule.self, from: data)
    }
}

enum RoutineLogKind: String, Codable, Equatable, Sendable {
    case completed
    case canceled
}

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var notes: String?
    var link: String?
    var deadline: Date?
    var priorityRawValue: String = RoutineTaskPriority.none.rawValue
    var importanceRawValue: String = RoutineTaskImportance.level2.rawValue
    var urgencyRawValue: String = RoutineTaskUrgency.level2.rawValue
    @Attribute(.externalStorage) var imageData: Data?
    var placeID: UUID?
    var tagsStorage: String = ""
    var stepsStorage: String = ""
    var checklistItemsStorage: String = ""
    var completedChecklistItemIDsStorage: String = ""
    var relationshipsStorage: String = ""
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
    var autoAssumeDailyDone: Bool = false

    var isPaused: Bool {
        pausedAt != nil
    }

    func isSnoozed(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let snoozedUntil else { return false }
        return calendar.startOfDay(for: referenceDate) < calendar.startOfDay(for: snoozedUntil)
    }

    func isArchived(
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        isPaused || isSnoozed(referenceDate: referenceDate, calendar: calendar)
    }

    var isPinned: Bool {
        pinnedAt != nil
    }

    /// Workflow state for one-off todos only. Nil for routines.
    /// Behavioral fields (pausedAt, lastDone) take precedence over the stored label
    /// so legacy tasks without todoStateRawValue are handled correctly.
    var todoState: TodoState? {
        guard isOneOffTask else { return nil }
        if pausedAt != nil { return .paused }
        if lastDone != nil || canceledAt != nil { return .done }
        if let raw = todoStateRawValue { return TodoState(rawValue: raw) ?? .ready }
        return .ready
    }

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

    var isOneOffTask: Bool {
        scheduleMode == .oneOff
    }

    var hasSequentialSteps: Bool {
        !steps.isEmpty
    }

    var hasChecklistItems: Bool {
        !checklistItems.isEmpty
    }

    var isChecklistDriven: Bool {
        scheduleMode == .derivedFromChecklist && hasChecklistItems
    }

    var isChecklistCompletionRoutine: Bool {
        scheduleMode == .fixedIntervalChecklist && hasChecklistItems
    }

    var usesRollingScheduleAnchor: Bool {
        recurrenceRule.kind == .intervalDays || isChecklistDriven
    }

    var isCompletedOneOff: Bool {
        isOneOffTask && lastDone != nil && canceledAt == nil && !isInProgress
    }

    var isCanceledOneOff: Bool {
        isOneOffTask && canceledAt != nil
    }

    var completedSteps: Int {
        max(min(Int(completedStepCount), steps.count), 0)
    }

    var totalSteps: Int {
        steps.count
    }

    var isInProgress: Bool {
        hasSequentialSteps && completedSteps > 0 && completedSteps < totalSteps
    }

    var currentStepNumber: Int? {
        guard hasSequentialSteps, completedSteps < totalSteps else { return nil }
        return completedSteps + 1
    }

    var nextStepTitle: String? {
        guard hasSequentialSteps, completedSteps < steps.count else { return nil }
        return steps[completedSteps].title
    }

    var completedChecklistItemCount: Int {
        let validIDs = Set(checklistItems.map(\.id))
        return completedChecklistItemIDs.intersection(validIDs).count
    }

    var totalChecklistItemCount: Int {
        checklistItems.count
    }

    var isChecklistInProgress: Bool {
        isChecklistCompletionRoutine
            && completedChecklistItemCount > 0
            && completedChecklistItemCount < totalChecklistItemCount
    }

    var nextPendingChecklistItemTitle: String? {
        guard isChecklistCompletionRoutine else { return nil }
        return checklistItems.first(where: { !completedChecklistItemIDs.contains($0.id) })?.title
    }

    func nextDueChecklistItem(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> RoutineChecklistItem? {
        guard isChecklistDriven else { return nil }
        return checklistItems.min {
            RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
        }
    }

    func dueChecklistItems(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [RoutineChecklistItem] {
        guard isChecklistDriven else { return [] }
        let dueBoundary = calendar.startOfDay(for: referenceDate)
        return checklistItems
            .filter { item in
                let dueDate = RoutineDateMath.dueDate(for: item, referenceDate: referenceDate, calendar: calendar)
                return calendar.startOfDay(for: dueDate) <= dueBoundary
            }
            .sorted {
                RoutineDateMath.dueDate(for: $0, referenceDate: referenceDate, calendar: calendar)
                    < RoutineDateMath.dueDate(for: $1, referenceDate: referenceDate, calendar: calendar)
            }
    }

    init(
        id: UUID = UUID(),
        name: String? = nil,
        emoji: String? = nil,
        notes: String? = nil,
        link: String? = nil,
        deadline: Date? = nil,
        priority: RoutineTaskPriority = .none,
        importance: RoutineTaskImportance = .level2,
        urgency: RoutineTaskUrgency = .level2,
        imageData: Data? = nil,
        placeID: UUID? = nil,
        tags: [String] = [],
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
        autoAssumeDailyDone: Bool = false
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
        self.priorityRawValue = priority.rawValue
        self.importanceRawValue = importance.rawValue
        self.urgencyRawValue = urgency.rawValue
        self.imageData = imageData
        self.placeID = placeID
        self.tagsStorage = RoutineTag.serialize(tags)
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
        self.autoAssumeDailyDone = autoAssumeDailyDone
        if self.steps.isEmpty || Int(self.completedStepCount) > self.steps.count {
            resetStepProgress()
        }
        sanitizeChecklistProgress()
    }

    func replaceSteps(_ updatedSteps: [RoutineStep]) {
        let sanitized = RoutineStep.sanitized(updatedSteps)
        let previous = steps
        stepsStorage = RoutineStepStorage.serialize(sanitized)

        if sanitized.isEmpty {
            resetStepProgress()
            return
        }

        if sanitized != previous || Int(completedStepCount) > sanitized.count {
            resetStepProgress()
        }
    }

    func replaceChecklistItems(_ updatedItems: [RoutineChecklistItem]) {
        checklistItemsStorage = RoutineChecklistItemStorage.serialize(updatedItems)
        sanitizeChecklistProgress()
    }

    func replaceRelationships(_ updatedRelationships: [RoutineTaskRelationship]) {
        relationshipsStorage = RoutineTaskRelationshipStorage.serialize(updatedRelationships, ownerID: id)
    }

    func shiftChecklistItems(by duration: TimeInterval) {
        guard duration > 0, hasChecklistItems else { return }
        checklistItems = checklistItems.map { item in
            RoutineChecklistItem(
                id: item.id,
                title: item.title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: item.lastPurchasedAt?.addingTimeInterval(duration),
                createdAt: item.createdAt.addingTimeInterval(duration)
            )
        }
    }

    func resetStepProgress() {
        completedStepCount = 0
        sequenceStartedAt = nil
    }

    func resetChecklistProgress() {
        completedChecklistItemIDsStorage = ""
    }

    func isChecklistItemCompleted(_ itemID: UUID) -> Bool {
        completedChecklistItemIDs.contains(itemID)
    }

    @discardableResult
    func markChecklistItemsPurchased(
        _ itemIDs: Set<UUID>,
        purchasedAt: Date
    ) -> Int {
        guard !isArchived(), isChecklistDriven, !itemIDs.isEmpty else { return 0 }

        var updatedCount = 0
        let updatedItems = checklistItems.map { item in
            guard itemIDs.contains(item.id) else { return item }
            updatedCount += 1
            return RoutineChecklistItem(
                id: item.id,
                title: item.title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: purchasedAt,
                createdAt: item.createdAt
            )
        }

        guard updatedCount > 0 else { return 0 }
        checklistItems = updatedItems
        recordCompletion(at: purchasedAt)
        return updatedCount
    }

    @discardableResult
    func markChecklistItemCompleted(
        _ itemID: UUID,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> RoutineAdvanceResult {
        guard !isArchived() else { return .ignoredPaused }
        guard isChecklistCompletionRoutine,
              checklistItems.contains(where: { $0.id == itemID }) else {
            return .ignoredAlreadyCompletedToday
        }

        if completedChecklistItemIDs.isEmpty,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt) {
            return .ignoredAlreadyCompletedToday
        }

        var updatedIDs = completedChecklistItemIDs
        let insertResult = updatedIDs.insert(itemID)
        guard insertResult.inserted else {
            return .advancedChecklist(
                completedItems: completedChecklistItemCount,
                totalItems: totalChecklistItemCount
            )
        }

        completedChecklistItemIDs = updatedIDs
        let completedCount = updatedIDs.count
        let totalCount = totalChecklistItemCount

        if completedCount < totalCount {
            return .advancedChecklist(completedItems: completedCount, totalItems: totalCount)
        }

        recordCompletion(at: completedAt)
        resetChecklistProgress()
        return .completedRoutine
    }

    @discardableResult
    func unmarkChecklistItemCompleted(_ itemID: UUID) -> Bool {
        guard isChecklistCompletionRoutine else { return false }

        var updatedIDs = completedChecklistItemIDs
        guard updatedIDs.remove(itemID) != nil else { return false }
        completedChecklistItemIDs = updatedIDs
        return true
    }

    @discardableResult
    func advance(completedAt: Date, calendar: Calendar = .current) -> RoutineAdvanceResult {
        guard !isArchived() else { return .ignoredPaused }

        if !hasSequentialSteps {
            if let lastDone, calendar.isDate(lastDone, inSameDayAs: completedAt) {
                return .ignoredAlreadyCompletedToday
            }
            recordCompletion(at: completedAt)
            return .completedRoutine
        }

        if completedSteps == 0,
           let lastDone,
           calendar.isDate(lastDone, inSameDayAs: completedAt) {
            return .ignoredAlreadyCompletedToday
        }

        if sequenceStartedAt == nil {
            sequenceStartedAt = completedAt
        }

        let nextCompletedStepCount = min(completedSteps + 1, totalSteps)
        if nextCompletedStepCount < totalSteps {
            completedStepCount = Int16(nextCompletedStepCount)
            return .advancedStep(completedSteps: nextCompletedStepCount, totalSteps: totalSteps)
        }

        recordCompletion(at: completedAt)
        resetStepProgress()
        return .completedRoutine
    }

    func refreshScheduleAnchorAfterRemovingLatestCompletion(
        remainingLatestCompletion: Date?
    ) {
        if usesRollingScheduleAnchor {
            if isArchived() {
                if let remainingLatestCompletion {
                    scheduleAnchor = remainingLatestCompletion
                } else {
                    scheduleAnchor = pausedAt
                }
            } else {
                scheduleAnchor = remainingLatestCompletion
            }
            return
        }

        if isArchived() {
            scheduleAnchor = pausedAt ?? scheduleAnchor
        } else if scheduleAnchor == nil {
            scheduleAnchor = remainingLatestCompletion
        }
    }

    private func shouldUpdateLastDone(with candidate: Date) -> Bool {
        guard let lastDone else { return true }
        return candidate > lastDone
    }

    private func recordCompletion(at completedAt: Date) {
        guard shouldUpdateLastDone(with: completedAt) else { return }
        lastDone = completedAt
        canceledAt = nil
        if usesRollingScheduleAnchor {
            scheduleAnchor = completedAt
        }
    }

    func cancelOneOff(at canceledAt: Date) -> Bool {
        guard isOneOffTask, !isArchived(), !isCompletedOneOff, !isCanceledOneOff else { return false }
        lastDone = nil
        self.canceledAt = canceledAt
        scheduleAnchor = nil
        resetStepProgress()
        resetChecklistProgress()
        return true
    }

    func removeCanceledState() {
        canceledAt = nil
    }

    private func sanitizeChecklistProgress() {
        guard isChecklistCompletionRoutine else {
            completedChecklistItemIDsStorage = ""
            return
        }

        let validIDs = Set(checklistItems.map(\.id))
        let sanitizedIDs = completedChecklistItemIDs.intersection(validIDs)
        completedChecklistItemIDsStorage = RoutineChecklistProgressStorage.serialize(sanitizedIDs)
    }

    static func trimmedName(_ name: String?) -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedName(_ name: String?) -> String? {
        guard let trimmed = trimmedName(name), !trimmed.isEmpty else { return nil }
        return trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func sanitizedNotes(_ notes: String?) -> String? {
        guard let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func sanitizedLink(_ link: String?) -> String? {
        guard var trimmed = link?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        if !trimmed.contains("://") {
            trimmed = "https://\(trimmed)"
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host?.isEmpty == false else {
            return nil
        }

        return url.absoluteString
    }

    var resolvedLinkURL: URL? {
        Self.sanitizedLink(link).flatMap(URL.init(string:))
    }

    static func sanitizedEmoji(_ input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }

    static func resolvedRelationships(
        for task: RoutineTask,
        within candidates: [RoutineTaskRelationshipCandidate]
    ) -> [RoutineTaskResolvedRelationship] {
        var resolvedByID: [String: RoutineTaskResolvedRelationship] = [:]
        let candidateByID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })

        for relationship in task.relationships {
            guard let candidate = candidateByID[relationship.targetTaskID] else { continue }
            let resolved = RoutineTaskResolvedRelationship(
                taskID: candidate.id,
                taskName: candidate.displayName,
                taskEmoji: candidate.emoji,
                kind: relationship.kind,
                status: candidate.status
            )
            resolvedByID[resolved.id] = resolved
        }

        for candidate in candidates {
            for relationship in candidate.relationships where relationship.targetTaskID == task.id {
                let resolved = RoutineTaskResolvedRelationship(
                    taskID: candidate.id,
                    taskName: candidate.displayName,
                    taskEmoji: candidate.emoji,
                    kind: relationship.kind.inverse,
                    status: candidate.status
                )
                resolvedByID[resolved.id] = resolved
            }
        }

        return resolvedByID.values.sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.taskName.localizedCaseInsensitiveCompare($1.taskName) == .orderedAscending
        }
    }

    static func removeRelationships(
        targeting deletedTaskIDs: Set<UUID>,
        from tasks: [RoutineTask]
    ) {
        guard !deletedTaskIDs.isEmpty else { return }
        for task in tasks where !deletedTaskIDs.contains(task.id) {
            let updatedRelationships = task.relationships.filter { !deletedTaskIDs.contains($0.targetTaskID) }
            if updatedRelationships != task.relationships {
                task.replaceRelationships(updatedRelationships)
            }
        }
    }

    func detachedCopy() -> RoutineTask {
        let copy = RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            notes: notes,
            link: link,
            deadline: deadline,
            priority: priority,
            importance: importance,
            urgency: urgency,
            imageData: imageData,
            placeID: placeID,
            tags: tags,
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
            autoAssumeDailyDone: autoAssumeDailyDone
        )
        copy.completedChecklistItemIDsStorage = completedChecklistItemIDsStorage
        copy.manualSectionOrderStorage = manualSectionOrderStorage
        copy.scheduleAnchor = scheduleAnchor
        return copy
    }
}

@Model
final class RoutineLog {
    var id: UUID = UUID()
    var timestamp: Date?
    var taskID: UUID = UUID()
    var kindRawValue: String = RoutineLogKind.completed.rawValue

    var kind: RoutineLogKind {
        get { RoutineLogKind(rawValue: kindRawValue) ?? .completed }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date? = nil,
        taskID: UUID,
        kind: RoutineLogKind = .completed
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
        self.kindRawValue = kind.rawValue
    }

    func detachedCopy() -> RoutineLog {
        RoutineLog(id: id, timestamp: timestamp, taskID: taskID, kind: kind)
    }
}

extension RoutineTask: Equatable {
    static func == (lhs: RoutineTask, rhs: RoutineTask) -> Bool {
        lhs.id == rhs.id
    }
}

extension RoutineLog: Equatable {
    static func == (lhs: RoutineLog, rhs: RoutineLog) -> Bool {
        lhs.id == rhs.id
    }
}
