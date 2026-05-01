#if canImport(AppIntents)
import AppIntents
import Foundation
import SwiftData

struct RoutinaQuickAddTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add Task"
    static let description = IntentDescription("Create a Routina task from natural language.")
    static let openAppWhenRun = false

    @Parameter(title: "Task")
    var text: String

    init() {
        text = ""
    }

    init(text: String) {
        self.text = text
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Quick add \(\.$text)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await RoutinaQuickAddService.createTask(
                from: text,
                context: PersistenceController.shared.container.mainContext
            )
            return .result(dialog: "Added \(result.taskName).")
        } catch {
            return .result(dialog: "\(error.localizedDescription)")
        }
    }
}

struct RoutinaMarkTaskDoneIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Task Done"
    static let description = IntentDescription("Mark the best matching Routina task as done.")
    static let openAppWhenRun = false

    @Parameter(title: "Task Name")
    var taskName: String?

    init() {
        taskName = nil
    }

    init(taskName: String?) {
        self.taskName = taskName
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await RoutinaQuickAddService.markBestMatchingTaskDone(
                named: taskName,
                context: PersistenceController.shared.container.mainContext
            )
            return .result(dialog: "\(result.message)")
        } catch {
            return .result(dialog: "\(error.localizedDescription)")
        }
    }
}

struct RoutinaStartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Start a focus session for a Routina task.")
    static let openAppWhenRun = false

    @Parameter(title: "Task Name")
    var taskName: String?

    @Parameter(title: "Duration Minutes")
    var durationMinutes: Int

    init() {
        taskName = nil
        durationMinutes = 25
    }

    init(taskName: String?, durationMinutes: Int = 25) {
        self.taskName = taskName
        self.durationMinutes = durationMinutes
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try RoutinaQuickAddService.startFocusSession(
                taskName: taskName,
                durationMinutes: durationMinutes,
                context: PersistenceController.shared.container.mainContext
            )
            return .result(dialog: "Started \(result.durationMinutes) minute focus for \(result.taskName).")
        } catch {
            return .result(dialog: "\(error.localizedDescription)")
        }
    }
}

struct RoutinaTodaySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Today in Routina"
    static let description = IntentDescription("Summarize what is due today in Routina.")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let summary = try RoutinaQuickAddService.todaySummary(
                context: PersistenceController.shared.container.mainContext
            )
            return .result(dialog: "\(summary)")
        } catch {
            return .result(dialog: "\(error.localizedDescription)")
        }
    }
}

struct RoutinaAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RoutinaQuickAddTaskIntent(),
            phrases: [
                "Quick add in \(.applicationName)",
                "Add a task in \(.applicationName)"
            ],
            shortTitle: "Quick Add",
            systemImageName: "text.badge.plus"
        )

        AppShortcut(
            intent: RoutinaMarkTaskDoneIntent(),
            phrases: [
                "Mark task done in \(.applicationName)",
                "Complete a task in \(.applicationName)"
            ],
            shortTitle: "Mark Done",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: RoutinaStartFocusIntent(),
            phrases: [
                "Start focus in \(.applicationName)",
                "Focus with \(.applicationName)"
            ],
            shortTitle: "Start Focus",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: RoutinaTodaySummaryIntent(),
            phrases: [
                "What's due in \(.applicationName)",
                "Today in \(.applicationName)"
            ],
            shortTitle: "Today",
            systemImageName: "calendar"
        )
    }
}
#endif
