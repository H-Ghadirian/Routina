import AppKit
import SwiftUI

extension Notification.Name {
    static let routinaMacOpenRoutinesInSidebar = Notification.Name("routina.mac.openRoutinesInSidebar")
    static let routinaMacOpenTimelineInSidebar = Notification.Name("routina.mac.openTimelineInSidebar")
    static let routinaMacOpenStatsInSidebar = Notification.Name("routina.mac.openStatsInSidebar")
    static let routinaMacOpenAddTask = Notification.Name("routina.mac.openAddTask")
    static let routinaMacOpenAddEvent = Notification.Name("routina.mac.openAddEvent")
    static let routinaMacOpenAddEmotion = Notification.Name("routina.mac.openAddEmotion")
    static let routinaMacOpenAddNote = Notification.Name("routina.mac.openAddNote")
    static let routinaMacOpenAddGoal = Notification.Name("routina.mac.openAddGoal")
    static let routinaMacOpenCheckIn = Notification.Name("routina.mac.openCheckIn")
    static let routinaMacOpenAway = Notification.Name("routina.mac.openAway")
    static let routinaMacFocusSearchOrCreate = Notification.Name("routina.mac.focusSearchOrCreate")
    static let routinaMacNavigateBack = Notification.Name("routina.mac.navigateBack")
    static let routinaMacNavigateForward = Notification.Name("routina.mac.navigateForward")
}

@MainActor
enum RoutinaMacSearchOrCreateFocus {
    static func request(retryAfterWindowOpen: Bool = false) {
        postFocusRequest()

        guard retryAfterWindowOpen else { return }
        [0.05, 0.15, 0.35, 0.7].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                postFocusRequest()
            }
        }
    }

    private static func postFocusRequest() {
        NotificationCenter.default.post(name: .routinaMacFocusSearchOrCreate, object: nil)
    }
}

struct RoutineCommands: Commands {
    @StateObject private var textEditingMonitor = RoutinaMacTextEditingMonitor.shared

    #if !SWIFT_PACKAGE
    @AppStorage(
        UserDefaultStringValueKey.macQuickAddShortcut.rawValue,
        store: SharedDefaults.app
    ) private var quickAddShortcutRawValue = MacQuickAddShortcut.defaultValue.rawValue
    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isPlacesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAwayEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAwayEnabled = false
    #endif

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                performUndo()
            }
            .keyboardShortcut("z", modifiers: .command)

            Button("Redo") {
                performRedo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(before: .appSettings) {
            #if !SWIFT_PACKAGE
            Button("Going to Sleep") {
                RoutinaMacSleepModeStarter.requestStartUsingSharedPersistence()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Divider()
            #endif

            Button("Search or Create") {
                RoutinaMacSearchOrCreateFocus.request()
            }
            .keyboardShortcut(quickAddShortcut.keyEquivalent, modifiers: quickAddShortcut.modifiers)

            Divider()

            #if !SWIFT_PACKAGE
            if areMacEventEmotionActionsEnabled {
                addMenuCommand(.event, notificationName: .routinaMacOpenAddEvent)
                addMenuCommand(.emotion, notificationName: .routinaMacOpenAddEmotion)
            }
            #endif

            #if !SWIFT_PACKAGE
            if isNotesEnabled {
                addMenuCommand(.note, notificationName: .routinaMacOpenAddNote)
            }
            #else
            addMenuCommand(.note, notificationName: .routinaMacOpenAddNote)
            #endif

            #if !SWIFT_PACKAGE
            if isGoalsTabEnabled {
                addMenuCommand(.goal, notificationName: .routinaMacOpenAddGoal)
            }
            #endif

            addMenuCommand(.task, notificationName: .routinaMacOpenAddTask)
            #if !SWIFT_PACKAGE
            if isPlacesEnabled {
                addMenuCommand(.checkIn, notificationName: .routinaMacOpenCheckIn)
            }
            #endif
            #if !SWIFT_PACKAGE
            if isAwayEnabled {
                addMenuCommand(.away, notificationName: .routinaMacOpenAway)
            }
            #else
            addMenuCommand(.away, notificationName: .routinaMacOpenAway)
            #endif

            Divider()

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

            Button("Timeline") {
                NotificationCenter.default.post(name: .routinaMacOpenTimelineInSidebar, object: nil)
            }
            .keyboardShortcut("3", modifiers: [.command, .option])
        }
    }

    private func addMenuCommand(
        _ shortcut: MacAddMenuShortcut,
        notificationName: Notification.Name
    ) -> some View {
        Button(shortcut.commandTitle) {
            NotificationCenter.default.post(name: notificationName, object: nil)
        }
        .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
    }

    private func performUndo() {
        if textEditingMonitor.isEditingText {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
            return
        }

        #if SWIFT_PACKAGE
        NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        #else
        if !RoutinaUndoSupport.performUndo() {
            NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
        }
        #endif
    }

    private func performRedo() {
        if textEditingMonitor.isEditingText {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
            return
        }

        #if SWIFT_PACKAGE
        NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        #else
        if !RoutinaUndoSupport.performRedo() {
            NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
        }
        #endif
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
