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

enum RoutineTaskPriority: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case urgent = "Urgent"

    var title: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .none:
            return 0
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        case .urgent:
            return 4
        }
    }

    var metadataLabel: String? {
        self == .none ? nil : title
    }
}

enum RoutineTaskRelationshipKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case related
    case blocks
    case blockedBy

    var title: String {
        switch self {
        case .related:
            return "Related"
        case .blocks:
            return "Blocks"
        case .blockedBy:
            return "Blocked by"
        }
    }

    var systemImage: String {
        switch self {
        case .related:
            return "link"
        case .blocks:
            return "arrow.turn.down.right"
        case .blockedBy:
            return "exclamationmark.triangle"
        }
    }

    var inverse: RoutineTaskRelationshipKind {
        switch self {
        case .related:
            return .related
        case .blocks:
            return .blockedBy
        case .blockedBy:
            return .blocks
        }
    }

    var sortOrder: Int {
        switch self {
        case .blockedBy:
            return 0
        case .blocks:
            return 1
        case .related:
            return 2
        }
    }
}

struct RoutineTaskRelationship: Codable, Equatable, Hashable, Identifiable, Sendable {
    var targetTaskID: UUID
    var kind: RoutineTaskRelationshipKind

    var id: String {
        "\(targetTaskID.uuidString)-\(kind.rawValue)"
    }

    static func sanitized(
        _ relationships: [RoutineTaskRelationship],
        ownerID: UUID? = nil
    ) -> [RoutineTaskRelationship] {
        var latestByTargetID: [UUID: RoutineTaskRelationship] = [:]
        for relationship in relationships {
            guard relationship.targetTaskID != ownerID else { continue }
            latestByTargetID[relationship.targetTaskID] = relationship
        }

        return latestByTargetID.values.sorted {
            if $0.kind.sortOrder != $1.kind.sortOrder {
                return $0.kind.sortOrder < $1.kind.sortOrder
            }
            return $0.targetTaskID.uuidString < $1.targetTaskID.uuidString
        }
    }
}

struct RoutineTaskRelationshipCandidate: Equatable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var emoji: String
    var relationships: [RoutineTaskRelationship]

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled task" : name
    }

    static func from(
        _ tasks: [RoutineTask],
        excluding excludedTaskID: UUID? = nil
    ) -> [RoutineTaskRelationshipCandidate] {
        tasks.compactMap { task in
            guard task.id != excludedTaskID else { return nil }
            return RoutineTaskRelationshipCandidate(
                id: task.id,
                name: task.name ?? "Untitled task",
                emoji: task.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
                relationships: task.relationships
            )
        }
        .sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }
}

struct RoutineTaskResolvedRelationship: Equatable, Hashable, Identifiable, Sendable {
    var taskID: UUID
    var taskName: String
    var taskEmoji: String
    var kind: RoutineTaskRelationshipKind

    var id: String {
        "\(taskID.uuidString)-\(kind.rawValue)"
    }
}

struct RoutineTimeOfDay: Codable, Equatable, Hashable, Sendable {
    var hour: Int
    var minute: Int

    init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    static let defaultValue = RoutineTimeOfDay(
        hour: NotificationPreferences.defaultReminderHour,
        minute: NotificationPreferences.defaultReminderMinute
    )

    static func from(
        _ date: Date,
        calendar: Calendar = .current
    ) -> RoutineTimeOfDay {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return RoutineTimeOfDay(
            hour: components.hour ?? defaultValue.hour,
            minute: components.minute ?? defaultValue.minute
        )
    }

    func date(
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let components = DateComponents(
            year: dayComponents.year,
            month: dayComponents.month,
            day: dayComponents.day,
            hour: hour,
            minute: minute
        )
        return calendar.date(from: components) ?? date
    }

    func formatted(calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date(on: Date(), calendar: calendar))
    }
}

struct RoutineRecurrenceRule: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
        case intervalDays
        case dailyTime
        case weekly
        case monthlyDay

        var pickerTitle: String {
            switch self {
            case .intervalDays:
                return "Interval"
            case .dailyTime:
                return "Time"
            case .weekly:
                return "Week"
            case .monthlyDay:
                return "Month"
            }
        }
    }

    var kind: Kind
    var interval: Int
    var timeOfDay: RoutineTimeOfDay?
    var weekday: Int?
    var dayOfMonth: Int?

    init(
        kind: Kind,
        interval: Int = 1,
        timeOfDay: RoutineTimeOfDay? = nil,
        weekday: Int? = nil,
        dayOfMonth: Int? = nil
    ) {
        self.kind = kind

        switch kind {
        case .intervalDays:
            self.interval = max(interval, 1)
            self.timeOfDay = nil
            self.weekday = nil
            self.dayOfMonth = nil

        case .dailyTime:
            self.interval = 1
            self.timeOfDay = timeOfDay ?? .defaultValue
            self.weekday = nil
            self.dayOfMonth = nil

        case .weekly:
            self.interval = 1
            self.timeOfDay = timeOfDay
            self.weekday = Self.clampedWeekday(weekday)
            self.dayOfMonth = nil

        case .monthlyDay:
            self.interval = 1
            self.timeOfDay = timeOfDay
            self.weekday = nil
            self.dayOfMonth = Self.clampedDayOfMonth(dayOfMonth)
        }
    }

    static func interval(days: Int) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .intervalDays, interval: days)
    }

    static func daily(at timeOfDay: RoutineTimeOfDay) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .dailyTime, timeOfDay: timeOfDay)
    }

    static func weekly(
        on weekday: Int,
        at timeOfDay: RoutineTimeOfDay? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .weekly, timeOfDay: timeOfDay, weekday: weekday)
    }

    static func monthly(
        on dayOfMonth: Int,
        at timeOfDay: RoutineTimeOfDay? = nil
    ) -> RoutineRecurrenceRule {
        RoutineRecurrenceRule(kind: .monthlyDay, timeOfDay: timeOfDay, dayOfMonth: dayOfMonth)
    }

    var isFixedCalendar: Bool {
        kind != .intervalDays
    }

    var approximateIntervalDays: Int {
        switch kind {
        case .intervalDays:
            return max(interval, 1)
        case .dailyTime:
            return 1
        case .weekly:
            return 7
        case .monthlyDay:
            return 30
        }
    }

    var usesExplicitTimeOfDay: Bool {
        timeOfDay != nil
    }

    func displayText(calendar: Calendar = .current) -> String {
        switch kind {
        case .intervalDays:
            let resolvedInterval = max(interval, 1)
            if resolvedInterval % 30 == 0 {
                let months = resolvedInterval / 30
                return months == 1 ? "Every month" : "Every \(months) months"
            }
            if resolvedInterval % 7 == 0 {
                let weeks = resolvedInterval / 7
                return weeks == 1 ? "Every week" : "Every \(weeks) weeks"
            }
            return resolvedInterval == 1 ? "Every day" : "Every \(resolvedInterval) days"

        case .dailyTime:
            let timeText = (timeOfDay ?? .defaultValue).formatted(calendar: calendar)
            return "Every day at \(timeText)"

        case .weekly:
            let weekdayName = Self.weekdayName(for: weekday ?? calendar.firstWeekday, calendar: calendar)
            if let timeOfDay {
                return "Every \(weekdayName) at \(timeOfDay.formatted(calendar: calendar))"
            }
            return "Every \(weekdayName)"

        case .monthlyDay:
            let ordinalDay = Self.ordinalString(for: dayOfMonth ?? 1)
            if let timeOfDay {
                return "Every \(ordinalDay) at \(timeOfDay.formatted(calendar: calendar))"
            }
            return "Every \(ordinalDay) of the month"
        }
    }

    private static func clampedWeekday(_ weekday: Int?) -> Int {
        min(max(weekday ?? Calendar.current.firstWeekday, 1), 7)
    }

    private static func clampedDayOfMonth(_ dayOfMonth: Int?) -> Int {
        min(max(dayOfMonth ?? Calendar.current.component(.day, from: Date()), 1), 31)
    }

    private static func weekdayName(
        for weekday: Int,
        calendar: Calendar
    ) -> String {
        let symbols = calendar.weekdaySymbols
        let safeIndex = min(max(weekday - 1, 0), max(symbols.count - 1, 0))
        return symbols[safeIndex]
    }

    private static func ordinalString(for day: Int) -> String {
        let resolvedDay = clampedDayOfMonth(day)
        let suffix: String
        switch resolvedDay % 100 {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch resolvedDay % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }
        return "\(resolvedDay)\(suffix)"
    }
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

@Model
final class RoutineTask {
    var id: UUID = UUID()
    var name: String?
    var emoji: String?
    var notes: String?
    var link: String?
    var deadline: Date?
    var priorityRawValue: String = RoutineTaskPriority.none.rawValue
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
        notes: String? = nil,
        link: String? = nil,
        deadline: Date? = nil,
        priority: RoutineTaskPriority = .none,
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
        scheduleAnchor: Date? = nil,
        pausedAt: Date? = nil,
        pinnedAt: Date? = nil,
        completedStepCount: Int16 = 0,
        sequenceStartedAt: Date? = nil
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
        recordCompletion(at: purchasedAt)
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
        guard !isPaused else { return .ignoredPaused }

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
            if isPaused {
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

        if isPaused {
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
        if usesRollingScheduleAnchor {
            scheduleAnchor = completedAt
        }
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
                kind: relationship.kind
            )
            resolvedByID[resolved.id] = resolved
        }

        for candidate in candidates {
            for relationship in candidate.relationships where relationship.targetTaskID == task.id {
                let resolved = RoutineTaskResolvedRelationship(
                    taskID: candidate.id,
                    taskName: candidate.displayName,
                    taskEmoji: candidate.emoji,
                    kind: relationship.kind.inverse
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
