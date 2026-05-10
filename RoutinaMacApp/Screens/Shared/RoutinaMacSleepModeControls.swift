import AppKit
import SwiftData
import SwiftUI

enum RoutinaMacSleepModeStarter {
    static func requestStartUsingSharedPersistence() {
        Task { @MainActor in
            requestStart(in: PersistenceController.shared.container.mainContext)
        }
    }

    @MainActor
    static func requestStart(in context: ModelContext) {
        do {
            guard try SleepSessionSupport.activeSession(in: context) == nil else {
                return
            }

            if let warningMessage = try SleepSessionSupport.activeFocusTimerWarningMessage(in: context),
               !confirmStoppingFocusTimer(message: warningMessage) {
                return
            }

            _ = try SleepSessionSupport.startSleep(in: context)
        } catch {
            showStartFailure(error)
        }
    }

    @MainActor
    private static func confirmStoppingFocusTimer(message: String) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Stop focus timer?"
        alert.informativeText = message
        alert.addButton(withTitle: "Start Sleep")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    private static func showStartFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not start sleep mode"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct RoutinaMacSleepToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            RoutinaMacSleepToolbarButton()
        }
    }
}

private struct RoutinaMacSleepToolbarButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var activeSleepSessions: [SleepSession]

    init() {
        _activeSleepSessions = Query(
            filter: #Predicate<SleepSession> { session in
                session.endedAt == nil
            },
            sort: \.startedAt,
            order: .reverse
        )
    }

    var body: some View {
        if activeSleepSessions.isEmpty {
            Button {
                RoutinaMacSleepModeStarter.requestStart(in: modelContext)
            } label: {
                Label("Going to sleep", systemImage: "bed.double.fill")
            }
            .help("Start sleep mode")
        }
    }
}
