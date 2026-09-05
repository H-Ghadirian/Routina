import Foundation

enum StatsAchievementCategory: String, Equatable {
    case total
    case blocks
    case streak
    case session
    case daily
    case weekly
    case comeback
    case sleep
    case sleepStreak
    case away
    case done
    case doneStreak
    case emotion
    case emotionStreak
    case place
    case placeStreak
    case goal
    case note
    case noteStreak
}

enum StatsAchievementDomain: String, CaseIterable, Equatable, Identifiable {
    case all
    case focus
    case sleep
    case away
    case done
    case emotions
    case places
    case goals
    case notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return String(localized: "All")
        case .focus:
            return String(localized: "Focus")
        case .sleep:
            return String(localized: "Sleep")
        case .away:
            return String(localized: "Away")
        case .done:
            return String(localized: "Done")
        case .emotions:
            return String(localized: "Emotions")
        case .places:
            return String(localized: "Places")
        case .goals:
            return String(localized: "Goals")
        case .notes:
            return String(localized: "Notes")
        }
    }
}

enum StatsAchievementUnit: Equatable {
    case seconds
    case count(singular: String, plural: String)

    func text(for value: Double) -> String {
        switch self {
        case .seconds:
            return Self.durationText(seconds: value)
        case let .count(singular, plural):
            let count = max(0, Int(value.rounded(.down)))
            return "\(count.formatted()) \(count == 1 ? singular : plural)"
        }
    }

    private static func durationText(seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded(.down)))
        guard totalMinutes > 0 else { return "0m" }

        if totalMinutes < 60 {
            return "\(totalMinutes)m"
        }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        guard minutes > 0 else { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

struct StatsAchievementProgress: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let domain: StatsAchievementDomain
    let category: StatsAchievementCategory
    let currentValue: Double
    let targetValue: Double
    let unit: StatsAchievementUnit

    var isEarned: Bool {
        currentValue >= targetValue
    }

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(currentValue / targetValue, 0), 1)
    }

    var progressText: String {
        "\(unit.text(for: currentValue)) / \(unit.text(for: targetValue))"
    }
}

typealias FocusAchievementCategory = StatsAchievementCategory
typealias FocusAchievementUnit = StatsAchievementUnit
typealias FocusAchievementProgress = StatsAchievementProgress
typealias FocusAchievementStats = StatsAchievementStats
