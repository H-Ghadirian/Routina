struct TaskFormDurationPreset: Identifiable, Hashable {
    let minutes: Int
    let label: String

    var id: Int { minutes }
}

enum TaskFormDurationEntryPresentation {
    static let estimatedDurationBounds = 5...10_080
    static let actualDurationBounds = 1...1_440

    static let durationPresets: [TaskFormDurationPreset] = [
        TaskFormDurationPreset(minutes: 15, label: "15m"),
        TaskFormDurationPreset(minutes: 30, label: "30m"),
        TaskFormDurationPreset(minutes: 60, label: "1h"),
        TaskFormDurationPreset(minutes: 120, label: "2h"),
        TaskFormDurationPreset(minutes: 240, label: "4h"),
        TaskFormDurationPreset(minutes: 480, label: "8h"),
        TaskFormDurationPreset(minutes: 1_200, label: "20h")
    ]

    static func clamped(_ minutes: Int, bounds: ClosedRange<Int>) -> Int {
        min(max(minutes, bounds.lowerBound), bounds.upperBound)
    }

    static func hours(for minutes: Int) -> Int {
        max(0, minutes) / 60
    }

    static func minuteRemainder(for minutes: Int) -> Int {
        max(0, minutes) % 60
    }

    static func combinedMinutes(
        hours: Int,
        minuteRemainder: Int,
        bounds: ClosedRange<Int>
    ) -> Int {
        let safeHours = max(0, hours)
        let safeMinutes = min(max(0, minuteRemainder), 59)
        return clamped((safeHours * 60) + safeMinutes, bounds: bounds)
    }
}
