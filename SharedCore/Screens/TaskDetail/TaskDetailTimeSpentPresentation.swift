import Foundation

enum TaskDetailTimeSpentPresentation {
    static let fallbackEntryMinutes = 25
    static let minimumMinutes = 1
    static let maximumMinutes = 1_440

    static func defaultEditMinutes(
        currentMinutes: Int?,
        estimatedMinutes: Int?
    ) -> Int {
        clampedMinutes(currentMinutes ?? estimatedMinutes ?? fallbackEntryMinutes)
    }

    static func defaultAdditionalEntryMinutes(
        currentMinutes: Int?,
        estimatedMinutes: Int?
    ) -> Int {
        currentMinutes == nil
            ? defaultEditMinutes(currentMinutes: nil, estimatedMinutes: estimatedMinutes)
            : fallbackEntryMinutes
    }

    static func clampedMinutes(_ minutes: Int) -> Int {
        min(max(minutes, minimumMinutes), maximumMinutes)
    }

    static func entryTotalMinutes(hours: Int, minutes: Int) -> Int {
        (max(hours, 0) * 60) + max(minutes, 0)
    }

    static func previewTotalMinutes(
        currentMinutes: Int?,
        entryMinutes: Int
    ) -> Int {
        (currentMinutes ?? 0) + entryMinutes
    }

    static func previewText(currentMinutes: Int?, entryMinutes: Int) -> String {
        let total = clampedMinutes(previewTotalMinutes(currentMinutes: currentMinutes, entryMinutes: entryMinutes))
        return "Total \(TaskDetailHeaderBadgePresentation.durationText(for: total))"
    }

    static func applyTitle(entryMinutes: Int) -> String {
        let text = TaskDetailHeaderBadgePresentation.durationText(for: clampedMinutes(entryMinutes))
        return "Add \(text)"
    }

    static func canApplyEntry(currentMinutes: Int?, entryMinutes: Int) -> Bool {
        let preview = previewTotalMinutes(currentMinutes: currentMinutes, entryMinutes: entryMinutes)
        return entryMinutes > 0
            && preview >= minimumMinutes
            && preview <= maximumMinutes
    }

    static func focusSessionMinutes(from seconds: TimeInterval) -> Int {
        clampedMinutes(Int((seconds / 60).rounded()))
    }
}
