import AppKit
import SwiftUI

extension NSMenu {
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

    fileprivate func assignRoutinaActionTarget(_ target: RoutinaMacContextMenuView) {
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
        createCustomSection: @escaping () -> Void,
        createBacklogSection: @escaping () -> Void
    ) {
        let item = NSMenuItem(title: "Move to", action: nil, keyEquivalent: "")
        item.image = NSImage(
            systemSymbolName: "arrow.up.arrow.down",
            accessibilityDescription: "Move to"
        )

        let submenu = NSMenu(title: "Move to")
        var hasSectionItems = false

        let topLevelSections = HomeCustomTaskSectionStorage.topLevelSections(in: customSections)
        let radarSections = topLevelSections.filter { $0.surface == .radar }
        let backlogSections = topLevelSections.filter { $0.surface == .backlog }

        for section in radarSections {
            let subsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: customSections
            )
            if subsections.isEmpty {
                submenu.addActionItem(
                    title: section.title,
                    systemImage: "rectangle.stack",
                    isEnabled: currentCustomSectionID != section.id && !section.isPaused
                ) {
                    moveToCustomSection(section.id)
                }
            } else {
                let sectionItem = NSMenuItem(
                    title: section.title,
                    action: nil,
                    keyEquivalent: ""
                )
                sectionItem.image = NSImage(
                    systemSymbolName: "rectangle.stack",
                    accessibilityDescription: section.title
                )
                let sectionSubmenu = NSMenu(title: section.title)
                sectionSubmenu.addActionItem(
                    title: "In \(section.title)",
                    systemImage: "rectangle.stack",
                    isEnabled: currentCustomSectionID != section.id && !section.isPaused
                ) {
                    moveToCustomSection(section.id)
                }
                for subsection in subsections {
                    sectionSubmenu.addActionItem(
                        title: subsection.title,
                        systemImage: "rectangle.inset.filled",
                        isEnabled: currentCustomSectionID != subsection.id && !section.isPaused
                    ) {
                        moveToCustomSection(subsection.id)
                    }
                }
                sectionItem.submenu = sectionSubmenu
                submenu.addItem(sectionItem)
            }
            hasSectionItems = true
        }

        if !backlogSections.isEmpty || !radarSections.isEmpty {
            submenu.addItem(.separator())
        }

        let backlogItem = NSMenuItem(title: "Backlog", action: nil, keyEquivalent: "")
        backlogItem.image = NSImage(
            systemSymbolName: "archivebox",
            accessibilityDescription: "Backlog"
        )
        let backlogSubmenu = NSMenu(title: "Backlog")
        for section in backlogSections {
            let subsections = HomeCustomTaskSectionStorage.subsections(
                of: section.id,
                in: customSections
            )
            if subsections.isEmpty {
                backlogSubmenu.addActionItem(
                    title: section.title,
                    systemImage: "rectangle.stack",
                    isEnabled: currentCustomSectionID != section.id && !section.isPaused
                ) {
                    moveToCustomSection(section.id)
                }
            } else {
                let sectionItem = NSMenuItem(title: section.title, action: nil, keyEquivalent: "")
                sectionItem.image = NSImage(
                    systemSymbolName: "rectangle.stack",
                    accessibilityDescription: section.title
                )
                let sectionSubmenu = NSMenu(title: section.title)
                sectionSubmenu.addActionItem(
                    title: "In \(section.title)",
                    systemImage: "rectangle.stack",
                    isEnabled: currentCustomSectionID != section.id && !section.isPaused
                ) {
                    moveToCustomSection(section.id)
                }
                for subsection in subsections {
                    sectionSubmenu.addActionItem(
                        title: subsection.title,
                        systemImage: "rectangle.inset.filled",
                        isEnabled: currentCustomSectionID != subsection.id && !section.isPaused
                    ) {
                        moveToCustomSection(subsection.id)
                    }
                }
                sectionItem.submenu = sectionSubmenu
                backlogSubmenu.addItem(sectionItem)
            }
        }
        if !backlogSections.isEmpty {
            backlogSubmenu.addItem(.separator())
        }
        backlogSubmenu.addActionItem(
            title: "New Backlog Super Section...",
            systemImage: "plus.rectangle",
            action: createBacklogSection
        )
        backlogItem.submenu = backlogSubmenu
        submenu.addItem(backlogItem)
        hasSectionItems = true

        submenu.addActionItem(
            title: "New Main Task List Super Section...",
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
