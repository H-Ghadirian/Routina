import SwiftUI

enum AwaySessionTimerMode: String, CaseIterable, Identifiable {
    case fixedDuration
    case countUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixedDuration:
            return "Duration"
        case .countUp:
            return "Count Up"
        }
    }
}

enum AwayStartPresetOption: Hashable, Identifiable {
    case away(AwaySessionPreset)
    case sleep

    static func options(includesSleep: Bool) -> [AwayStartPresetOption] {
        var options = AwaySessionPreset.allCases.map(AwayStartPresetOption.away)
        if includesSleep {
            options.append(.sleep)
        }
        return options
    }

    var id: String {
        switch self {
        case let .away(preset):
            return preset.rawValue
        case .sleep:
            return "sleep"
        }
    }

    var awayPreset: AwaySessionPreset? {
        guard case let .away(preset) = self else { return nil }
        return preset
    }

    var isSleep: Bool {
        self == .sleep
    }
}

enum AwaySessionStartPresentation {
    case sheet
    case inline
}

extension AwaySessionPreset {
    var tint: Color {
        switch self {
        case .wake:
            return .orange
        case .reset:
            return .teal
        case .outside:
            return .green
        case .windDown:
            return .indigo
        case .meal:
            return .pink
        case .custom:
            return .cyan
        }
    }

    var actionTint: Color {
        switch self {
        case .wake:
            return Color(red: 0.96, green: 0.57, blue: 0.16)
        default:
            return tint
        }
    }

    var actionForeground: Color {
        switch self {
        case .windDown:
            return .white
        default:
            return Color.black.opacity(0.84)
        }
    }

    var defaultDurationText: String {
        "\(defaultDurationMinutes)m default"
    }

    var startLine: String {
        switch self {
        case .wake:
            return "A clean first pocket away from the screen."
        case .reset:
            return "A short reset before the next thing."
        case .outside:
            return "A protected walk or errand."
        case .windDown:
            return "A softer landing before rest."
        case .meal:
            return "A meal without the app pulling you back."
        case .custom:
            return "A flexible away session."
        }
    }
}

extension AwaySessionPreset: Identifiable {
    var id: String { rawValue }
}

extension AwayStartPresetOption {
    var title: String {
        switch self {
        case let .away(preset):
            return preset.title
        case .sleep:
            return "Sleep"
        }
    }

    var systemImage: String {
        switch self {
        case let .away(preset):
            return preset.systemImage
        case .sleep:
            return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case let .away(preset):
            return preset.tint
        case .sleep:
            return .orange
        }
    }

    var actionTint: Color {
        switch self {
        case let .away(preset):
            return preset.actionTint
        case .sleep:
            return Color(red: 0.96, green: 0.57, blue: 0.16)
        }
    }

    var actionForeground: Color {
        switch self {
        case let .away(preset):
            return preset.actionForeground
        case .sleep:
            return Color.black.opacity(0.84)
        }
    }

    var defaultDurationText: String {
        switch self {
        case let .away(preset):
            return preset.defaultDurationText
        case .sleep:
            return "\(sleepDurationText) target"
        }
    }

    var modeEyebrow: String {
        isSleep ? "Sleep mode" : "Away mode"
    }

    var startLine: String {
        switch self {
        case let .away(preset):
            return preset.startLine
        case .sleep:
            return "A protected wind-down for real rest."
        }
    }

    var startActionTitle: String {
        isSleep ? "Start Sleep" : "Start Away"
    }

    var startActionSystemImage: String {
        isSleep ? "bed.double.fill" : "lock.shield.fill"
    }

    func timerSummary(timerMode: AwaySessionTimerMode, durationMinutes: Int) -> String {
        guard !isSleep else { return sleepDurationText }
        return timerMode == .fixedDuration ? "\(durationMinutes)m" : "Count up"
    }

    func timerCaption(timerMode: AwaySessionTimerMode) -> String {
        guard !isSleep else { return "sleep target" }
        return timerMode == .fixedDuration ? "protected timer" : "open timer"
    }

    func timerText(timerMode: AwaySessionTimerMode, durationMinutes: Int) -> String {
        guard !isSleep else { return "\(sleepDurationText) target" }
        return timerMode == .fixedDuration ? "\(durationMinutes)m duration" : "Count up"
    }

    func timerSystemImage(timerMode: AwaySessionTimerMode) -> String {
        guard !isSleep else { return "alarm.fill" }
        return timerMode == .fixedDuration ? "timer" : "infinity"
    }

    private var sleepDurationText: String {
        SleepSessionFormatting.durationText(seconds: 8 * 60 * 60)
    }
}
