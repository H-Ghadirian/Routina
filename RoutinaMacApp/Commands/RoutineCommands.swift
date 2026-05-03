import SwiftUI

extension Notification.Name {
    static let routinaMacOpenRoutinesInSidebar = Notification.Name("routina.mac.openRoutinesInSidebar")
    static let routinaMacOpenTimelineInSidebar = Notification.Name("routina.mac.openTimelineInSidebar")
    static let routinaMacOpenStatsInSidebar = Notification.Name("routina.mac.openStatsInSidebar")
    static let routinaMacOpenAddTask = Notification.Name("routina.mac.openAddTask")
    static let routinaMacOpenQuickAdd = Notification.Name("routina.mac.openQuickAdd")
}

struct RoutineCommands: Commands {
    @AppStorage(
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
        store: SharedDefaults.app
    ) private var quickAddShortcutRawValue = MacQuickAddShortcut.defaultValue.rawValue

    var body: some Commands {
        CommandGroup(before: .appSettings) {
            Button("Quick Add") {
                NotificationCenter.default.post(name: .routinaMacOpenQuickAdd, object: nil)
            }
            .keyboardShortcut(quickAddShortcut.keyEquivalent, modifiers: quickAddShortcut.eventModifiers)

            Button("Routines") {
                NotificationCenter.default.post(name: .routinaMacOpenRoutinesInSidebar, object: nil)
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Stats") {
                NotificationCenter.default.post(name: .routinaMacOpenStatsInSidebar, object: nil)
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Timeline") {
                NotificationCenter.default.post(name: .routinaMacOpenTimelineInSidebar, object: nil)
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
        }
    }

    private var quickAddShortcut: MacQuickAddShortcut {
        MacQuickAddShortcut(rawValue: quickAddShortcutRawValue) ?? .defaultValue
    }
}
