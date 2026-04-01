import SwiftUI

enum RoutinaMacWindowID {
    static let stats = "stats-window"
    static let timeline = "timeline-window"
}

struct RoutineCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(before: .appSettings) {
            Button("Stats") {
                openWindow(id: RoutinaMacWindowID.stats)
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Timeline") {
                openWindow(id: RoutinaMacWindowID.timeline)
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
        }
    }
}
