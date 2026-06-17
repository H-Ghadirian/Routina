import AppKit
import SwiftUI

extension HomeTCAView {
    var homeTaskRowCommandHandler: HomeTaskRowCommandHandler {
        HomeTaskRowCommandHandler(
            open: { openTask($0) },
            resume: { store.send(.resumeTask($0)) },
            markDone: { store.send(.markTaskDone($0)) },
            markMissed: { store.send(.markTaskMissed($0)) },
            markCanceled: { store.send(.markTaskCanceled($0)) },
            notToday: { store.send(.notTodayTask($0)) },
            pause: { store.send(.pauseTask($0)) },
            moveTaskInSection: { taskID, sectionKey, orderedTaskIDs, direction in
                store.send(
                    .moveTaskInSection(
                        taskID: taskID,
                        sectionKey: sectionKey,
                        orderedTaskIDs: orderedTaskIDs,
                        direction: direction
                    )
                )
            },
            pin: { store.send(.pinTask($0)) },
            unpin: { store.send(.unpinTask($0)) },
            delete: { deleteTask($0) }
        )
    }

    func routineNavigationRow(
        for task: HomeFeature.RoutineDisplay,
        rowNumber: Int,
        includeMarkDone: Bool = true,
        moveContext: HomeTaskListMoveContext? = nil
    ) -> some View {
        platformRoutineNavigationRow(
            for: task,
            rowNumber: rowNumber,
            includeMarkDone: includeMarkDone,
            moveContext: moveContext
        )
    }

    var planningDatePickerPresentedBinding: Binding<Bool> {
        Binding(
            get: { planningDateTaskID != nil },
            set: { isPresented in
                if !isPresented {
                    dismissPlanningDatePicker()
                }
            }
        )
    }

    func presentPlanningDatePicker(for task: HomeFeature.RoutineDisplay) {
        planningDateTaskID = task.taskID
        planningDateDraft = task.plannedDate ?? Date()
    }

    func savePlanningDatePicker() {
        guard let taskID = planningDateTaskID else { return }
        store.send(.planTask(taskID, planningDateDraft))
        dismissPlanningDatePicker()
    }

    func planTaskForTodayFromContextMenu(_ taskID: UUID) {
        revealPlannedTodaySection(for: taskID)
        store.send(.planTask(taskID, calendar.startOfDay(for: Date())))
    }

    func dismissPlanningDatePicker() {
        planningDateTaskID = nil
    }

    func routineNativeContextMenu(
        for task: HomeFeature.RoutineDisplay,
        includeMarkDone: Bool,
        moveContext: HomeTaskListMoveContext? = nil
    ) -> NSMenu {
        let presentation = HomeTaskRowActionPresentation.make(
            for: task,
            includeMarkDone: includeMarkDone,
            moveContext: moveContext,
            allowsPinning: true
        )
        let menu = NSMenu()

        menu.addActionItem(
            title: "Open",
            systemImage: "arrow.right.circle"
        ) {
            homeTaskRowCommandHandler.handle(presentation.openCommand)
        }

        for action in presentation.lifecycleActions {
            menu.addActionItem(
                title: action.title,
                systemImage: action.systemImage,
                isEnabled: !action.isDisabled
            ) {
                homeTaskRowCommandHandler.handle(action.command(taskID: task.taskID))
            }
        }

        if !presentation.moveActions.isEmpty {
            menu.addItem(.separator())

            for action in presentation.moveActions {
                menu.addActionItem(
                    title: action.title,
                    systemImage: action.systemImage,
                    isEnabled: !action.isDisabled
                ) {
                    homeTaskRowCommandHandler.handle(action.command(taskID: task.taskID))
                }
            }
        }

        if !task.isDailyRoutine || presentation.notTodayCommand != nil {
            menu.addItem(.separator())
            menu.addPlanToDoSubmenu(
                for: task,
                notTodayCommand: presentation.notTodayCommand,
                commandHandler: homeTaskRowCommandHandler,
                planToday: {
                    planTaskForTodayFromContextMenu(task.taskID)
                },
                chooseDate: {
                    presentPlanningDatePicker(for: task)
                },
                clearPlan: {
                    store.send(.planTask(task.taskID, nil))
                }
            )
        }

        if let pinAction = presentation.pinAction {
            menu.addActionItem(
                title: pinAction.title,
                systemImage: pinAction.systemImage
            ) {
                homeTaskRowCommandHandler.handle(pinAction.command)
            }
        }

        menu.addActionItem(
            title: "Delete",
            systemImage: "trash"
        ) {
            homeTaskRowCommandHandler.handle(presentation.deleteCommand)
        }

        return menu
    }

    private func revealPlannedTodaySection(for taskID: UUID) {
        let sectionID = "\(HomeTaskListPresentationSectionKind.plannedToday.rawValue):Plan to do today"
        var collapsedSectionIDs = Set(
            collapsedTagTaskListSectionIDsStorage
                .split(separator: "\n")
                .map(String.init)
        )
        collapsedSectionIDs.remove(sectionID)
        collapsedTagTaskListSectionIDsStorage = collapsedSectionIDs.sorted().joined(separator: "\n")
        macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(taskID: taskID, anchor: .center)
    }
}

private extension NSMenu {
    @discardableResult
    func addActionItem(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(RoutinaMacContextMenuView.performMenuAction(_:)),
            keyEquivalent: ""
        )
        item.representedObject = RoutinaMacMenuAction(action: action)
        item.isEnabled = isEnabled
        item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        addItem(item)
        return item
    }

    func assignRoutinaActionTarget(_ target: RoutinaMacContextMenuView) {
        for item in items {
            if item.representedObject is RoutinaMacMenuAction {
                item.target = target
            }
            if let submenu = item.submenu {
                submenu.assignRoutinaActionTarget(target)
            }
        }
    }

    func addPlanToDoSubmenu(
        for task: HomeFeature.RoutineDisplay,
        notTodayCommand: HomeTaskRowCommand?,
        commandHandler: HomeTaskRowCommandHandler,
        planToday: @escaping () -> Void,
        chooseDate: @escaping () -> Void,
        clearPlan: @escaping () -> Void
    ) {
        let item = NSMenuItem(title: "Plan to do", action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "calendar.badge.clock",
            accessibilityDescription: "Plan to do"
        )

        let submenu = NSMenu(title: "Plan to do")

        if !task.isDailyRoutine {
            submenu.addActionItem(title: "Today", systemImage: "calendar", action: planToday)
            submenu.addActionItem(
                title: "Choose Date...",
                systemImage: "calendar.badge.plus",
                action: chooseDate
            )

            if task.plannedDate != nil {
                submenu.addActionItem(
                    title: "Clear Plan",
                    systemImage: "xmark.circle",
                    action: clearPlan
                )
            }
        }

        if !task.isDailyRoutine, notTodayCommand != nil {
            submenu.addItem(.separator())
        }

        if let notTodayCommand {
            submenu.addActionItem(title: "Not today", systemImage: "moon.zzz") {
                commandHandler.handle(notTodayCommand)
            }
        }

        item.submenu = submenu
        addItem(item)
    }
}

private final class RoutinaMacMenuAction: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    func perform() {
        action()
    }
}

private struct RoutinaMacContextMenuModifier: ViewModifier {
    let makeMenu: () -> NSMenu

    func body(content: Content) -> some View {
        content.overlay {
            RoutinaMacContextMenuOverlay(makeMenu: makeMenu)
        }
    }
}

private struct RoutinaMacContextMenuOverlay: NSViewRepresentable {
    let makeMenu: () -> NSMenu

    func makeNSView(context: Context) -> RoutinaMacContextMenuView {
        RoutinaMacContextMenuView(makeMenu: makeMenu)
    }

    func updateNSView(_ nsView: RoutinaMacContextMenuView, context: Context) {
        nsView.makeMenu = makeMenu
    }
}

private final class RoutinaMacContextMenuView: NSView {
    var makeMenu: () -> NSMenu

    init(makeMenu: @escaping () -> NSMenu) {
        self.makeMenu = makeMenu
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let event = window?.currentEvent else { return nil }
        switch event.type {
        case .rightMouseDown:
            return self
        case .leftMouseDown where event.modifierFlags.contains(.control):
            return self
        default:
            return nil
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        showMenu(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showMenu(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    private func showMenu(with event: NSEvent) {
        let menu = makeMenu()
        menu.assignRoutinaActionTarget(self)
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc func performMenuAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? RoutinaMacMenuAction else { return }
        action.perform()
    }
}

extension View {
    func routinaMacContextMenu(makeMenu: @escaping () -> NSMenu) -> some View {
        modifier(RoutinaMacContextMenuModifier(makeMenu: makeMenu))
    }
}
