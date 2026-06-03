import AppKit
import SwiftUI

extension Notification.Name {
    static let routinaMacOpenRoutinesInSidebar = Notification.Name("routina.mac.openRoutinesInSidebar")
    static let routinaMacOpenAdventureInSidebar = Notification.Name("routina.mac.openAdventureInSidebar")
    static let routinaMacOpenTimelineInSidebar = Notification.Name("routina.mac.openTimelineInSidebar")
    static let routinaMacOpenStatsInSidebar = Notification.Name("routina.mac.openStatsInSidebar")
    static let routinaMacOpenAddTask = Notification.Name("routina.mac.openAddTask")
    static let routinaMacOpenQuickAdd = Notification.Name("routina.mac.openQuickAdd")
    static let routinaMacNavigateBack = Notification.Name("routina.mac.navigateBack")
    static let routinaMacNavigateForward = Notification.Name("routina.mac.navigateForward")
}

struct RoutineCommands: Commands {
    @StateObject private var textEditingMonitor = RoutinaMacTextEditingMonitor.shared

    #if !SWIFT_PACKAGE
    @AppStorage(
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
        store: SharedDefaults.app
    ) private var quickAddShortcutRawValue = MacQuickAddShortcut.defaultValue.rawValue
    #endif

    var body: some Commands {
        CommandGroup(before: .appSettings) {
            #if !SWIFT_PACKAGE
            Button("Going to Sleep") {
                RoutinaMacSleepModeStarter.requestStartUsingSharedPersistence()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()
            #endif

            Button("Quick Add") {
                NotificationCenter.default.post(name: .routinaMacOpenQuickAdd, object: nil)
            }
            .keyboardShortcut(quickAddShortcut.keyEquivalent, modifiers: quickAddShortcut.modifiers)

            Button("Back") {
                NotificationCenter.default.post(name: .routinaMacNavigateBack, object: nil)
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command])
            .disabled(textEditingMonitor.isEditingText)

            Button("Forward") {
                NotificationCenter.default.post(name: .routinaMacNavigateForward, object: nil)
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command])
            .disabled(textEditingMonitor.isEditingText)

            Divider()

            Button("Routines") {
                NotificationCenter.default.post(name: .routinaMacOpenRoutinesInSidebar, object: nil)
            }
            .keyboardShortcut("1", modifiers: [.command, .option])

            Button("Stats") {
                NotificationCenter.default.post(name: .routinaMacOpenStatsInSidebar, object: nil)
            }
            .keyboardShortcut("2", modifiers: [.command, .option])

            Button("Adventure") {
                NotificationCenter.default.post(name: .routinaMacOpenAdventureInSidebar, object: nil)
            }
            .keyboardShortcut("3", modifiers: [.command, .option])

            Button("Timeline") {
                NotificationCenter.default.post(name: .routinaMacOpenTimelineInSidebar, object: nil)
            }
            .keyboardShortcut("4", modifiers: [.command, .option])
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

@MainActor
private final class RoutinaMacTextEditingMonitor: ObservableObject {
    static let shared = RoutinaMacTextEditingMonitor()

    @Published private(set) var isEditingText = false

    private var observers: [NSObjectProtocol] = []

    private init() {
        refresh()

        let notificationCenter = NotificationCenter.default
        [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSControl.textDidBeginEditingNotification,
            NSControl.textDidEndEditingNotification,
            NSText.didBeginEditingNotification,
            NSText.didEndEditingNotification
        ].forEach { name in
            observers.append(
                notificationCenter.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.refresh()
                    }
                }
            )
        }
    }

    private func refresh() {
        isEditingText = Self.isTextEditingInKeyWindow
    }

    private static var isTextEditingInKeyWindow: Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else {
            return false
        }

        if firstResponder is NSTextView
            || firstResponder is NSTextField
            || firstResponder is NSSearchField
            || firstResponder is NSText {
            return true
        }

        return false
    }
}
