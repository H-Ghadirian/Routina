import SwiftUI

enum StatsAchievementStatusFilter: String, CaseIterable, Identifiable {
    case inProgress
    case achieved

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inProgress:
            return "In Progress"
        case .achieved:
            return "Achieved"
        }
    }

    var systemImage: String {
        switch self {
        case .inProgress:
            return "clock.fill"
        case .achieved:
            return "checkmark.seal.fill"
        }
    }

    var emptyStateSystemImage: String {
        switch self {
        case .inProgress:
            return "checkmark.seal"
        case .achieved:
            return "medal"
        }
    }

    func groupTitle(period: StatsAchievementCelebrationPeriod) -> String {
        switch self {
        case .inProgress:
            return "In Progress"
        case .achieved:
            return "Achieved \(period.title)"
        }
    }
}

extension StatsAchievementCelebrationPeriod {
    var emptyStateSuffix: String {
        switch self {
        case .today:
            return "today"
        case .week:
            return "this week"
        case .month:
            return "this month"
        case .year:
            return "this year"
        }
    }
}

extension StatsAchievementDomain {
    var accentColor: Color {
        switch self {
        case .all:
            return .accentColor
        case .focus:
            return .teal
        case .sleep:
            return .purple
        case .away:
            return .cyan
        case .done:
            return .green
        case .emotions:
            return .pink
        case .places:
            return .teal
        case .goals:
            return .yellow
        case .notes:
            return .blue
        }
    }
}

extension StatsAchievementCategory {
    var accentColor: Color {
        switch self {
        case .total:
            return .teal
        case .blocks:
            return .mint
        case .streak:
            return .orange
        case .session:
            return .blue
        case .daily:
            return .indigo
        case .weekly:
            return .green
        case .comeback:
            return .pink
        case .sleep:
            return .purple
        case .sleepStreak:
            return .indigo
        case .away:
            return .cyan
        case .done:
            return .green
        case .doneStreak:
            return .orange
        case .emotion:
            return .pink
        case .emotionStreak:
            return .red
        case .place:
            return .cyan
        case .placeStreak:
            return .teal
        case .goal:
            return .yellow
        case .note:
            return .blue
        case .noteStreak:
            return .indigo
        }
    }
}
