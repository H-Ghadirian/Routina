import SwiftUI

enum RoutinaMacWindowID {
    static let stats = "stats-window"
}

struct RoutineCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(before: .appSettings) {
            Button("Stats") {
                openWindow(id: RoutinaMacWindowID.stats)
            }
        }
    }
}
