import Foundation
import SwiftData

struct RoutineStep: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String

    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }

    static func sanitized(_ steps: [RoutineStep]) -> [RoutineStep] {
        steps.compactMap { step in
            guard let title = normalizedTitle(step.title) else { return nil }
            return RoutineStep(id: step.id, title: title)
        }
    }

    static func normalizedTitle(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

enum RoutineTaskType: String, CaseIterable, Equatable, Hashable, Sendable {
    case routine = "Routine"
    case todo = "Todo"
}

enum RoutineScheduleMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case fixedInterval
    case fixedIntervalChecklist
    case derivedFromChecklist
    case oneOff

    var taskType: RoutineTaskType {
        self == .oneOff ? .todo : .routine
    }
}

struct RoutineChecklistItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var intervalDays: Int
    var lastPurchasedAt: Date?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String,
        intervalDays: Int,
        lastPurchasedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.intervalDays = Self.clampedIntervalDays(intervalDays)
        self.lastPurchasedAt = lastPurchasedAt
        self.createdAt = createdAt
    }

    static func sanitized(_ items: [RoutineChecklistItem]) -> [RoutineChecklistItem] {
        items.compactMap { item in
            guard let title = normalizedTitle(item.title) else { return nil }
            return RoutineChecklistItem(
                id: item.id,
                title: title,
                intervalDays: item.intervalDays,
                lastPurchasedAt: item.lastPurchasedAt,
                createdAt: item.createdAt
            )
        }
    }

    static func normalizedTitle(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    static func clampedIntervalDays(_ value: Int) -> Int {
        min(max(value, 1), 3650)
    }
}

enum RoutineAdvanceResult: Equatable {
    case ignoredPaused
    case ignoredAlreadyCompletedToday
    case advancedStep(completedSteps: Int, totalSteps: Int)
    case advancedChecklist(completedItems: Int, totalItems: Int)
    case completedRoutine
}

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

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var placeID: UUID?
    var tagsStorage: String = ""
    var stepsStorage: String = ""
    var checklistItemsStorage: String = ""
    var completedChecklistItemIDsStorage: String = ""
    var scheduleModeRawValue: String = RoutineScheduleMode.fixedInterval.rawValue
    var interval: Int16 = 1
    var lastDone: Date?
    var scheduleAnchor: Date?
    var pausedAt: Date?
    var pinnedAt: Date?
    var completedStepCount: Int16 = 0
    var sequenceStartedAt: Date?

    var isPaused: Bool {
        pausedAt != nil
    }

    var isPinned: Bool {
        pinnedAt != nil
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

    var scheduleMode: RoutineScheduleMode {
        get { RoutineScheduleMode(rawValue: scheduleModeRawValue) ?? .fixedInterval }
        set {
            scheduleModeRawValue = newValue.rawValue
            if newValue == .oneOff {
                checklistItemsStorage = ""
                completedChecklistItemIDsStorage = ""
            }
            sanitizeChecklistProgress()
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

    var isCompletedOneOff: Bool {
        isOneOffTask && lastDone != nil && !isInProgress
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
        placeID: UUID? = nil,
        tags: [String] = [],
        steps: [RoutineStep] = [],
        checklistItems: [RoutineChecklistItem] = [],
        scheduleMode: RoutineScheduleMode? = nil,
        interval: Int16 = 1,
        lastDone: Date? = nil,
        scheduleAnchor: Date? = nil,
        pausedAt: Date? = nil,
        pinnedAt: Date? = nil,
        completedStepCount: Int16 = 0,
        sequenceStartedAt: Date? = nil
    ) {
        let resolvedScheduleMode = scheduleMode ?? (checklistItems.isEmpty ? .fixedInterval : .derivedFromChecklist)
        let resolvedChecklistItems = resolvedScheduleMode == .oneOff ? [] : checklistItems
        self.id = id
        self.name = name
        self.emoji = emoji
        self.placeID = placeID
        self.tagsStorage = RoutineTag.serialize(tags)
        self.stepsStorage = RoutineStepStorage.serialize(steps)
        self.checklistItemsStorage = RoutineChecklistItemStorage.serialize(resolvedChecklistItems)
        self.scheduleModeRawValue = resolvedScheduleMode.rawValue
        self.interval = resolvedScheduleMode == .oneOff ? 1 : interval
        self.lastDone = lastDone
        self.scheduleAnchor = resolvedScheduleMode == .oneOff ? lastDone : (scheduleAnchor ?? lastDone)
        self.pausedAt = pausedAt
        self.pinnedAt = pinnedAt
        self.completedStepCount = Int16(max(Int(completedStepCount), 0))
        self.sequenceStartedAt = sequenceStartedAt
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
        guard !isPaused, isChecklistDriven, !itemIDs.isEmpty else { return 0 }

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
        if shouldUpdateLastDone(with: purchasedAt) {
            lastDone = purchasedAt
            scheduleAnchor = purchasedAt
        }
        return updatedCount
    }

    @discardableResult
    func markChecklistItemCompleted(
        _ itemID: UUID,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> RoutineAdvanceResult {
        guard !isPaused else { return .ignoredPaused }
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

        if shouldUpdateLastDone(with: completedAt) {
            lastDone = completedAt
            scheduleAnchor = completedAt
        }
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
        guard !isPaused else { return .ignoredPaused }

        if !hasSequentialSteps {
            if let lastDone, calendar.isDate(lastDone, inSameDayAs: completedAt) {
                return .ignoredAlreadyCompletedToday
            }
            if shouldUpdateLastDone(with: completedAt) {
                lastDone = completedAt
                scheduleAnchor = completedAt
            }
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

        if shouldUpdateLastDone(with: completedAt) {
            lastDone = completedAt
            scheduleAnchor = completedAt
        }
        resetStepProgress()
        return .completedRoutine
    }

    private func shouldUpdateLastDone(with candidate: Date) -> Bool {
        guard let lastDone else { return true }
        return candidate > lastDone
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

    static func sanitizedEmoji(_ input: String, fallback: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return fallback }
        return String(first)
    }

    func detachedCopy() -> RoutineTask {
        let copy = RoutineTask(
            id: id,
            name: name,
            emoji: emoji,
            placeID: placeID,
            tags: tags,
            steps: steps,
            checklistItems: checklistItems,
            scheduleMode: scheduleMode,
            interval: interval,
            lastDone: lastDone,
            scheduleAnchor: scheduleAnchor,
            pausedAt: pausedAt,
            pinnedAt: pinnedAt,
            completedStepCount: completedStepCount,
            sequenceStartedAt: sequenceStartedAt
        )
        copy.completedChecklistItemIDsStorage = completedChecklistItemIDsStorage
        copy.scheduleAnchor = scheduleAnchor
        return copy
    }
}

@Model
final class RoutineLog {
    var id: UUID = UUID()
    var timestamp: Date?
    var taskID: UUID = UUID()

    init(
        id: UUID = UUID(),
        timestamp: Date? = nil,
        taskID: UUID
    ) {
        self.id = id
        self.timestamp = timestamp
        self.taskID = taskID
    }

    func detachedCopy() -> RoutineLog {
        RoutineLog(id: id, timestamp: timestamp, taskID: taskID)
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
