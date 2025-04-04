import SwiftUI

extension Notification.Name {
    static let routinaMacOpenRoutinesInSidebar = Notification.Name("routina.mac.openRoutinesInSidebar")
    static let routinaMacOpenTimelineInSidebar = Notification.Name("routina.mac.openTimelineInSidebar")
    static let routinaMacOpenStatsInSidebar = Notification.Name("routina.mac.openStatsInSidebar")
}

struct RoutineCommands: Commands {
    var body: some Commands {
        CommandGroup(before: .appSettings) {
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
}
