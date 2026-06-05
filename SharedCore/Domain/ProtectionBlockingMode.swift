import Foundation

enum ProtectionBlockingMode: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case focus
    case away
    case sleep

    var id: String { rawValue }

    static var defaultEnabledModes: Set<ProtectionBlockingMode> {
        Set(allCases)
    }

    var title: String {
        switch self {
        case .focus:
            return "Focus"
        case .away:
            return "Away"
        case .sleep:
            return "Sleep"
        }
    }

    var label: String {
        switch self {
        case .focus:
            return "During Focus"
        case .away:
            return "During Away"
        case .sleep:
            return "During Sleep"
        }
    }

    var settingsDescription: String {
        switch self {
        case .focus:
            return "Blocks while an unpaused focus timer is running."
        case .away:
            return "Blocks while an Away session is active."
        case .sleep:
            return "Blocks while Sleep mode is active."
        }
    }

    var systemImage: String {
        switch self {
        case .focus:
            return "timer"
        case .away:
            return "lock.shield.fill"
        case .sleep:
            return "bed.double.fill"
        }
    }

    static func decodedSet(from rawValue: String?) -> Set<ProtectionBlockingMode> {
        guard let rawValue else { return defaultEnabledModes }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return Set(
            trimmed
                .split(separator: ",")
                .compactMap { ProtectionBlockingMode(rawValue: String($0)) }
        )
    }

    static func encodedSet(_ modes: Set<ProtectionBlockingMode>) -> String {
        modes
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }
}
