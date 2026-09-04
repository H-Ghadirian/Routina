import Foundation

struct DayPlanFocusedSleep: Equatable {
    let sessionID: UUID
    let startMinute: Int
    private let token = UUID()

    var scrollTargetID: UUID {
        token
    }
}

enum DayPlanVisibleRangeMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case day
    case threeDays
    case week

    var id: Self { self }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .threeDays:
            return "3 Days"
        case .week:
            return "Week"
        }
    }

    var navigationDayCount: Int {
        visibleDayCount
    }

    var visibleDayCount: Int {
        switch self {
        case .day:
            return 1
        case .threeDays:
            return 3
        case .week:
            return 7
        }
    }
}

enum DayPlanDisplayMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case calendar
    case list

    var id: Self { self }

    var title: String {
        switch self {
        case .calendar:
            return "Calendar"
        case .list:
            return "Timeline"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar:
            return "calendar"
        case .list:
            return "list.bullet"
        }
    }
}

enum DayPlanCalendarTaskViewMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case schedule
    case list

    var id: Self { self }

    var title: String {
        switch self {
        case .schedule:
            return "Schedule"
        case .list:
            return "List"
        }
    }

    var systemImage: String {
        switch self {
        case .schedule:
            return "clock"
        case .list:
            return "list.bullet"
        }
    }
}

enum DayPlanHourSpacing: String, CaseIterable, Identifiable {
    case standard
    case spacious
    case expanded

    var id: Self { self }

    var hourHeight: Double {
        switch self {
        case .standard:
            return 64
        case .spacious:
            return 88
        case .expanded:
            return 112
        }
    }

    var next: Self {
        switch self {
        case .standard:
            return .spacious
        case .spacious:
            return .expanded
        case .expanded:
            return .expanded
        }
    }

    var previous: Self {
        switch self {
        case .standard:
            return .standard
        case .spacious:
            return .standard
        case .expanded:
            return .spacious
        }
    }
}

struct MacPlannerPresentationPreferences: Codable, Equatable, Sendable {
    var displayMode: DayPlanDisplayMode = .calendar
    var calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule
    var visibleRangeMode: DayPlanVisibleRangeMode = .week

    static let `default` = Self()

    init(
        displayMode: DayPlanDisplayMode = .calendar,
        calendarTaskViewMode: DayPlanCalendarTaskViewMode = .schedule,
        visibleRangeMode: DayPlanVisibleRangeMode = .week
    ) {
        self.displayMode = displayMode
        self.calendarTaskViewMode = calendarTaskViewMode
        self.visibleRangeMode = visibleRangeMode
    }

    private enum CodingKeys: String, CodingKey {
        case displayMode
        case calendarTaskViewMode
        case visibleRangeMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayMode = try container.decodeIfPresent(DayPlanDisplayMode.self, forKey: .displayMode) ?? .calendar
        calendarTaskViewMode =
            try container.decodeIfPresent(
                DayPlanCalendarTaskViewMode.self,
                forKey: .calendarTaskViewMode
            ) ?? .schedule
        visibleRangeMode =
            try container.decodeIfPresent(
                DayPlanVisibleRangeMode.self,
                forKey: .visibleRangeMode
            ) ?? .week
    }
}

enum MacPlannerPresentationPreferencesStore {
    static func load(
        from defaults: UserDefaults = SharedDefaults.app
    ) -> MacPlannerPresentationPreferences {
        guard
            let rawValue = defaults[.appSettingMacPlannerPresentationPreferences],
            let data = rawValue.data(using: .utf8),
            let preferences = try? JSONDecoder().decode(MacPlannerPresentationPreferences.self, from: data)
        else {
            return .default
        }
        return preferences
    }

    @discardableResult
    static func update(
        in defaults: UserDefaults = SharedDefaults.app,
        _ changes: (inout MacPlannerPresentationPreferences) -> Void
    ) -> Bool {
        var preferences = load(from: defaults)
        let previousPreferences = preferences
        changes(&preferences)
        guard preferences != previousPreferences,
            let data = try? JSONEncoder().encode(preferences),
            let rawValue = String(data: data, encoding: .utf8)
        else {
            return false
        }
        defaults[.appSettingMacPlannerPresentationPreferences] = rawValue
        return true
    }
}
