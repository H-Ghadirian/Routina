import SwiftUI

extension Notification.Name {
    static let routinaMacOpenRoutinesInSidebar = Notification.Name("routina.mac.openRoutinesInSidebar")
    static let routinaMacOpenTimelineInSidebar = Notification.Name("routina.mac.openTimelineInSidebar")
    static let routinaMacOpenStatsInSidebar = Notification.Name("routina.mac.openStatsInSidebar")
    static let routinaMacOpenAddTask = Notification.Name("routina.mac.openAddTask")
    static let routinaMacOpenQuickAdd = Notification.Name("routina.mac.openQuickAdd")
}

struct RoutineCommands: Commands {
    #if !SWIFT_PACKAGE
    @AppStorage(
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
        store: SharedDefaults.app
    ) private var quickAddShortcutRawValue = MacQuickAddShortcut.defaultValue.rawValue
    #endif

    var body: some Commands {
        CommandGroup(before: .appSettings) {
            Button("Quick Add") {
                NotificationCenter.default.post(name: .routinaMacOpenQuickAdd, object: nil)
            }
            .keyboardShortcut(quickAddShortcut.keyEquivalent, modifiers: quickAddShortcut.modifiers)

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

    private var quickAddShortcut: (keyEquivalent: KeyEquivalent, modifiers: EventModifiers) {
        #if SWIFT_PACKAGE
        ("n", [.option, .command])
        #else
        {
            let shortcut = MacQuickAddShortcut(rawValue: quickAddShortcutRawValue) ?? .defaultValue
            return (shortcut.keyEquivalent, shortcut.eventModifiers)
        }()
        #endif
    }
}
