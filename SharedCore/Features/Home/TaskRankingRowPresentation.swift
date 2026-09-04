import Foundation

enum TaskRankingRowTone: Equatable, Sendable {
    case secondary
    case blue
    case orange
    case red
    case teal
}

struct TaskRankingRowPresentation: Equatable, Identifiable, Sendable {
    struct Status: Equatable, Sendable {
        let title: String
        let systemImage: String
        let tone: TaskRankingRowTone
    }

    let id: UUID
    let name: String
    let emoji: String
    let hasImage: Bool
    let isOneOffTask: Bool
    let color: RoutineTaskColor
    let status: Status?
    let scheduleText: String?
    let pressureText: String?
    let progressText: String?
    let stepsText: String?
    let placeText: String?
    let tags: [String]
    let flags: [String]

    static func make(
        task: RoutineTask,
        isContainerGroup: Bool,
        flagRules: [RoutineFlagRule],
        referenceDate: Date,
        calendar: Calendar
    ) -> Self {
        guard !isContainerGroup else {
            return Self(
                id: task.id,
                name: RoutineTask.trimmedName(task.name) ?? "Untitled group",
                emoji: CalendarTaskImportSupport.displayEmoji(for: task.emoji) ?? "📁",
                hasImage: false,
                isOneOffTask: true,
                color: task.color,
                status: nil,
                scheduleText: nil,
                pressureText: nil,
                progressText: nil,
                stepsText: nil,
                placeText: nil,
                tags: [],
                flags: []
            )
        }

        let base = BacklogTaskRowPresentation.make(
            task: task,
            flagRules: flagRules,
            referenceDate: referenceDate,
            calendar: calendar
        )
        return Self(
            id: base.id,
            name: base.name,
            emoji: base.emoji,
            hasImage: base.hasImage,
            isOneOffTask: base.isOneOffTask,
            color: base.color,
            status: base.status.map {
                Status(
                    title: $0.title,
                    systemImage: $0.systemImage,
                    tone: tone(from: $0.tone)
                )
            },
            scheduleText: base.scheduleText,
            pressureText: base.pressureText,
            progressText: base.progressText,
            stepsText: base.stepsText,
            placeText: base.placeText,
            tags: base.tags,
            flags: base.flags
        )
    }

    func metadataText(for visibility: HomeTaskRowVisibility, showsPlaces: Bool) -> String? {
        let items: [String?] = [
            visibility.shows(.schedule) ? scheduleText : nil,
            visibility.shows(.pressure) ? pressureText : nil,
            visibility.shows(.progress) ? progressText : nil,
            visibility.shows(.steps) ? stepsText : nil,
            showsPlaces && visibility.shows(.place) ? placeText : nil,
        ]
        let visibleItems = items.compactMap { $0 }
        return visibleItems.isEmpty ? nil : visibleItems.joined(separator: " • ")
    }

    private static func tone(from tone: BacklogTaskRowTone) -> TaskRankingRowTone {
        switch tone {
        case .secondary: return .secondary
        case .blue: return .blue
        case .orange: return .orange
        case .red: return .red
        case .teal: return .teal
        }
    }
}
