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

    func confirmAssumedTaskDone(_ taskID: UUID) {
        store.send(.confirmAssumedTaskDone(taskID))
    }

    func markAssumedTaskMissed(_ taskID: UUID) {
        store.send(.markAssumedTaskMissed(taskID))
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

    func planTaskForTomorrowFromContextMenu(_ taskID: UUID) {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        revealPlannedTomorrowDestination(for: taskID)
        store.send(.planTask(taskID, calendar.startOfDay(for: tomorrow)))
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

        menu.addItem(.separator())
        menu.addMoveToSubmenu(
            actions: presentation.moveActions,
            customSections: customTaskSections,
            currentCustomSectionID: task.customTaskSectionID,
            defaultSectionTitle: defaultTaskSectionTitle(for: task),
            taskID: task.taskID,
            commandHandler: homeTaskRowCommandHandler,
            moveToCustomSection: { sectionID in
                moveTaskToCustomSection(task.taskID, sectionID: sectionID)
            },
            createCustomSection: {
                presentCustomTaskSectionPrompt(for: task.taskID)
            }
        )

        let supportsPlanning = RoutineTaskPlanningSupport.supportsStoredPlanning(
            scheduleMode: task.scheduleMode,
            trackingCadenceEnabled: task.trackingCadenceEnabled,
            isDailyRoutine: task.isDailyRoutine
        )

        if supportsPlanning || presentation.notTodayCommand != nil {
            menu.addItem(.separator())
            menu.addPlanToDoSubmenu(
                for: task,
                supportsPlanning: supportsPlanning,
                includesTomorrow: showsTomorrowInTaskList,
                notTodayCommand: presentation.notTodayCommand,
                commandHandler: homeTaskRowCommandHandler,
                planToday: {
                    planTaskForTodayFromContextMenu(task.taskID)
                },
                planTomorrow: {
                    planTaskForTomorrowFromContextMenu(task.taskID)
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
        let sectionID = "\(HomeTaskListPresentationSectionKind.plannedToday.rawValue):plannedToday"
        revealTaskListSection(sectionID: sectionID, taskID: taskID)
    }

    private func revealPlannedTomorrowDestination(for taskID: UUID) {
        let sectionID = "\(HomeTaskListPresentationSectionKind.plannedTomorrow.rawValue):plannedTomorrow"
        revealTaskListSection(sectionID: sectionID, taskID: taskID)
    }

    func moveTaskToCustomSection(_ taskID: UUID, sectionID: UUID?) {
        if let sectionID {
            revealCustomTaskSection(sectionID, taskID: taskID)
        }
        store.send(.moveTaskToCustomSection(taskID: taskID, sectionID: sectionID))
    }

    var customTaskSections: [HomeCustomTaskSection] {
        HomeCustomTaskSectionStorage.decoded(from: customTaskSectionsRawValue)
    }

    func presentCustomTaskSectionPrompt(for taskID: UUID?) {
        pendingCustomTaskSectionTaskID = taskID
        customTaskSectionNameDraft = ""
        isCustomTaskSectionPromptPresented = true
    }

    func confirmCustomTaskSectionPrompt() {
        guard let result = HomeCustomTaskSectionStorage.upsertingSection(
            title: customTaskSectionNameDraft,
            in: customTaskSections
        ) else {
            return
        }

        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(result.sections)
        AppSettingsPersistenceMirror.schedule()
        if let taskID = pendingCustomTaskSectionTaskID {
            moveTaskToCustomSection(taskID, sectionID: result.section.id)
        }
        resetCustomTaskSectionPrompt()
    }

    func resetCustomTaskSectionPrompt() {
        isCustomTaskSectionPromptPresented = false
        customTaskSectionNameDraft = ""
        pendingCustomTaskSectionTaskID = nil
    }

    func presentCustomTaskSectionRenamePrompt(sectionID: UUID, title: String) {
        pendingRenameCustomTaskSectionID = sectionID
        customTaskSectionRenameDraft = title
        isCustomTaskSectionRenamePromptPresented = true
    }

    func confirmCustomTaskSectionRename() {
        guard let sectionID = pendingRenameCustomTaskSectionID,
              let sections = HomeCustomTaskSectionStorage.renamingSection(
                sectionID,
                title: customTaskSectionRenameDraft,
                in: customTaskSections
              ) else {
            return
        }

        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(sections)
        AppSettingsPersistenceMirror.schedule()
        resetCustomTaskSectionRenamePrompt()
    }

    func resetCustomTaskSectionRenamePrompt() {
        isCustomTaskSectionRenamePromptPresented = false
        pendingRenameCustomTaskSectionID = nil
        customTaskSectionRenameDraft = ""
    }

    func presentCustomTaskSectionDeleteConfirmation(sectionID: UUID, title: String) {
        pendingDeleteCustomTaskSectionID = sectionID
        pendingDeleteCustomTaskSectionTitle = title
        isCustomTaskSectionDeleteConfirmationPresented = true
    }

    func confirmCustomTaskSectionDeletion() {
        guard let sectionID = pendingDeleteCustomTaskSectionID else {
            resetCustomTaskSectionDeleteConfirmation()
            return
        }

        customTaskSectionsRawValue = HomeCustomTaskSectionStorage.encoded(
            HomeCustomTaskSectionStorage.deletingSection(sectionID, from: customTaskSections)
        )
        AppSettingsPersistenceMirror.schedule()
        removeCustomTaskSectionCollapseState(sectionID)
        store.send(.deleteCustomTaskSection(sectionID: sectionID))
        resetCustomTaskSectionDeleteConfirmation()
    }

    func resetCustomTaskSectionDeleteConfirmation() {
        isCustomTaskSectionDeleteConfirmationPresented = false
        pendingDeleteCustomTaskSectionID = nil
        pendingDeleteCustomTaskSectionTitle = ""
    }

    func applyCustomTaskSectionPrompt<Content: View>(to view: Content) -> some View {
        view.alert("New Section", isPresented: $isCustomTaskSectionPromptPresented) {
            TextField("Name", text: $customTaskSectionNameDraft)
            Button("Create") {
                confirmCustomTaskSectionPrompt()
            }
            .disabled(HomeCustomTaskSectionStorage.sanitizedTitle(customTaskSectionNameDraft) == nil)
            Button("Cancel", role: .cancel) {
                resetCustomTaskSectionPrompt()
            }
        }
    }

    func applyCustomTaskSectionRenamePrompt<Content: View>(to view: Content) -> some View {
        view.alert("Rename Section", isPresented: $isCustomTaskSectionRenamePromptPresented) {
            TextField("Name", text: $customTaskSectionRenameDraft)
            Button("Save") {
                confirmCustomTaskSectionRename()
            }
            .disabled(
                pendingRenameCustomTaskSectionID.flatMap { sectionID in
                    HomeCustomTaskSectionStorage.renamingSection(
                        sectionID,
                        title: customTaskSectionRenameDraft,
                        in: customTaskSections
                    )
                } == nil
            )
            Button("Cancel", role: .cancel) {
                resetCustomTaskSectionRenamePrompt()
            }
        }
    }

    func applyCustomTaskSectionDeleteConfirmation<Content: View>(to view: Content) -> some View {
        view.alert("Delete Section?", isPresented: $isCustomTaskSectionDeleteConfirmationPresented) {
            Button("Delete", role: .destructive) {
                confirmCustomTaskSectionDeletion()
            }
            Button("Cancel", role: .cancel) {
                resetCustomTaskSectionDeleteConfirmation()
            }
        } message: {
            Text("Are you sure you want to delete \"\(pendingDeleteCustomTaskSectionTitle)\"? Tasks in this section will move back to their default sections.")
        }
    }

    private func revealCustomTaskSection(_ customSectionID: UUID, taskID: UUID) {
        revealTaskListSection(sectionID: customTaskListSectionID(for: customSectionID), taskID: taskID)
    }

    private func removeCustomTaskSectionCollapseState(_ customSectionID: UUID) {
        var collapsedSectionIDs = collapsedTagTaskListSectionIDs
        collapsedSectionIDs.remove(customTaskListSectionID(for: customSectionID))
        collapsedTagTaskListSectionIDsStorage = collapsedSectionIDs.sorted().joined(separator: "\n")
    }

    private func customTaskListSectionID(for customSectionID: UUID) -> String {
        "\(HomeTaskListPresentationSectionKind.custom.rawValue):\(HomeCustomTaskSectionStorage.manualOrderSectionKey(for: customSectionID))"
    }

    private func revealTaskListSection(sectionID: String, taskID: UUID) {
        var collapsedSectionIDs = collapsedTagTaskListSectionIDs
        collapsedSectionIDs.remove(sectionID)
        collapsedTagTaskListSectionIDsStorage = collapsedSectionIDs.sorted().joined(separator: "\n")
        macSidebarTaskScrollRequest = MacSidebarTaskScrollRequest(taskID: taskID, anchor: .center)
    }

    private func defaultTaskSectionTitle(for task: HomeFeature.RoutineDisplay) -> String {
        if task.scheduleMode.taskType == .record {
            return "Tracking"
        }
        if task.isDailyRoutine {
            return "Today"
        }
        return "Future"
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
        supportsPlanning: Bool,
        includesTomorrow: Bool,
        notTodayCommand: HomeTaskRowCommand?,
        commandHandler: HomeTaskRowCommandHandler,
        planToday: @escaping () -> Void,
        planTomorrow: @escaping () -> Void,
        chooseDate: @escaping () -> Void,
        clearPlan: @escaping () -> Void
    ) {
        let item = NSMenuItem(title: "Plan to do", action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "calendar.badge.clock",
            accessibilityDescription: "Plan to do"
        )

        let submenu = NSMenu(title: "Plan to do")

        if supportsPlanning {
            submenu.addActionItem(title: "Today", systemImage: "calendar", action: planToday)
            if includesTomorrow {
                submenu.addActionItem(title: "Tomorrow", systemImage: "calendar.badge.clock", action: planTomorrow)
            }
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

        if supportsPlanning, notTodayCommand != nil {
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

    func addMoveToSubmenu(
        actions: [HomeTaskRowMoveActionPresentation],
        customSections: [HomeCustomTaskSection],
        currentCustomSectionID: UUID?,
        defaultSectionTitle: String,
        taskID: UUID,
        commandHandler: HomeTaskRowCommandHandler,
        moveToCustomSection: @escaping (UUID?) -> Void,
        createCustomSection: @escaping () -> Void
    ) {
        let item = NSMenuItem(title: "Move to", action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "arrow.up.arrow.down",
            accessibilityDescription: "Move to"
        )

        let submenu = NSMenu(title: "Move to")
        var hasSectionItems = false

        for section in customSections {
            submenu.addActionItem(
                title: section.title,
                systemImage: "rectangle.stack",
                isEnabled: currentCustomSectionID != section.id
            ) {
                moveToCustomSection(section.id)
            }
            hasSectionItems = true
        }

        submenu.addActionItem(
            title: "New Section...",
            systemImage: "plus.rectangle"
        ) {
            createCustomSection()
        }
        hasSectionItems = true

        if currentCustomSectionID != nil {
            submenu.addActionItem(
                title: defaultSectionTitle,
                systemImage: "arrow.uturn.backward"
            ) {
                moveToCustomSection(nil)
            }
            hasSectionItems = true
        }

        if hasSectionItems && !actions.isEmpty {
            submenu.addItem(.separator())
        }

        for action in actions {
            submenu.addActionItem(
                title: action.title,
                systemImage: action.systemImage,
                isEnabled: !action.isDisabled
            ) {
                commandHandler.handle(action.command(taskID: taskID))
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
