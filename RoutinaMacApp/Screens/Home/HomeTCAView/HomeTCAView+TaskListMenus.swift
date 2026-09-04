import ComposableArchitecture
import AppKit
import SwiftUI

extension HomeTCAView {
    func taskListSectionNativeContextMenu(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        in presentation: HomeTaskListPresentation<HomeFeature.RoutineDisplay>
    ) -> NSMenu {
        let menu = NSMenu(title: section.title)
        let showsFutureSubsectionActions = section.kind == .future && section.taskGroups.contains { $0.isCollapsible }
        let customSectionID = customTaskSectionID(for: section)
        let isCustomSectionPaused = customSectionID.map(isCustomSuperSectionPaused) ?? false

        if let customSectionID, !isCustomSectionPaused {
            menu.addActionItem(title: "New Task", systemImage: "plus") {
                store.send(.openAddTaskInCustomSection(customSectionID))
            }
        }

        if showsFutureSubsectionActions {
            menu.addActionItem(title: "Expand All", systemImage: "chevron.down.2") {
                expandAllFutureTaskListSubsections(in: section)
            }

            menu.addActionItem(title: "Collapse All Subsections", systemImage: "chevron.right.2") {
                collapseAllFutureTaskListSubsections(in: section)
            }
        }

        if let customSectionID {
            menu.addActionItem(
                title: isCustomSectionPaused ? "Resume Section" : "Pause Section",
                systemImage: isCustomSectionPaused ? "play.circle" : "pause.circle"
            ) {
                toggleCustomSuperSectionPause(customSectionID)
            }

            menu.addActionItem(title: "New Subsection", systemImage: "plus.rectangle.on.rectangle") {
                presentCustomTaskSectionPrompt(for: nil, parentSectionID: customSectionID)
            }

            menu.addActionItem(title: "Rename Section", systemImage: "pencil") {
                presentCustomTaskSectionRenamePrompt(sectionID: customSectionID, title: section.title)
            }

            menu.addActionItem(title: "Delete Section", systemImage: "trash") {
                presentCustomTaskSectionDeleteConfirmation(sectionID: customSectionID, title: section.title)
            }
        }

        if section.kind.isMacSidebarMoveMenuEligible {
            addTaskListSectionMenuSeparatorIfNeeded(to: menu)
            let visibleIDs = presentation.sections
                .filter(\.kind.isMacSidebarReorderable)
                .map(\.id)

            menu.addActionItem(
                title: "Move Up",
                systemImage: "arrow.up",
                isEnabled: HomeMacTaskListSectionOrder.canMove(
                    section.id,
                    by: -1,
                    visibleIDs: visibleIDs
                )
            ) {
                moveMacTaskListSection(section.id, by: -1, in: presentation)
            }

            menu.addActionItem(
                title: "Move Down",
                systemImage: "arrow.down",
                isEnabled: HomeMacTaskListSectionOrder.canMove(
                    section.id,
                    by: 1,
                    visibleIDs: visibleIDs
                )
            ) {
                moveMacTaskListSection(section.id, by: 1, in: presentation)
            }
        }

        if areMacHomeSectionFocusTimersEnabled, section.canStartFocusTimer {
            addTaskListSectionMenuSeparatorIfNeeded(to: menu)
            menu.addItem(.sectionHeader(title: "Focus Timer"))
            addTaskListSectionFocusItems(to: menu, for: section)
        }

        return menu
    }

    func taskListSectionHasContextMenu(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> Bool {
        let hasFutureSubsectionActions = section.kind == .future && section.taskGroups.contains { $0.isCollapsible }
        let hasCustomSectionActions = customTaskSectionID(for: section) != nil
        let hasFocusActions = areMacHomeSectionFocusTimersEnabled && section.canStartFocusTimer
        return section.kind.isMacSidebarMoveMenuEligible
            || hasFutureSubsectionActions
            || hasCustomSectionActions
            || hasFocusActions
    }

    private func addTaskListSectionMenuSeparatorIfNeeded(to menu: NSMenu) {
        guard !menu.items.isEmpty, menu.items.last?.isSeparatorItem != true else { return }
        menu.addItem(.separator())
    }

    private func customTaskSectionID(
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) -> UUID? {
        guard section.kind == .custom else { return nil }
        return HomeCustomTaskSectionStorage.sectionID(fromManualOrderSectionKey: section.identityKey)
    }

    func taskListGroupHasContextMenu(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> Bool {
        customTaskSectionID(for: group) != nil
            || (areMacHomeSectionFocusTimersEnabled && group.canStartFocusTimer)
    }

    func taskListGroupNativeContextMenu(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> NSMenu {
        let menu = NSMenu(title: group.title ?? "Focus Timer")
        if let customSectionID = customTaskSectionID(for: group) {
            menu.addActionItem(title: "New Task", systemImage: "plus") {
                store.send(.openAddTaskInCustomSection(customSectionID))
            }
        }
        if areMacHomeSectionFocusTimersEnabled, group.canStartFocusTimer {
            if customTaskSectionID(for: group) != nil {
                menu.addItem(.separator())
            }
            menu.addItem(.sectionHeader(title: "Focus Timer"))
            addTaskListGroupFocusItems(to: menu, for: group)
        }
        return menu
    }

    private func customTaskSectionID(
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) -> UUID? {
        guard group.kind == .custom,
            let identityKey = group.identityKey
        else {
            return nil
        }
        return HomeCustomTaskSectionStorage.sectionID(fromManualOrderSectionKey: identityKey)
    }

    private func addTaskListSectionFocusItems(
        to menu: NSMenu,
        for section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>
    ) {
        if section.canStartFocusTimer {
            menu.addActionItem(title: "Count up", systemImage: "stopwatch") {
                startFocusFromTaskListSection(section, duration: 0)
            }

            menu.addItem(.separator())

            for duration in planFocusDurationOptions {
                menu.addActionItem(
                    title: FocusSessionFormatting.compactDurationText(seconds: duration),
                    systemImage: "timer"
                ) {
                    startFocusFromTaskListSection(section, duration: duration)
                }
            }
        }
    }

    private func addTaskListGroupFocusItems(
        to menu: NSMenu,
        for group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>
    ) {
        if group.canStartFocusTimer {
            menu.addActionItem(title: "Count up", systemImage: "stopwatch") {
                startFocusFromTaskListGroup(group, duration: 0)
            }

            menu.addItem(.separator())

            for duration in planFocusDurationOptions {
                menu.addActionItem(
                    title: FocusSessionFormatting.compactDurationText(seconds: duration),
                    systemImage: "timer"
                ) {
                    startFocusFromTaskListGroup(group, duration: duration)
                }
            }
        }
    }

    private var planFocusDurationOptions: [TimeInterval] {
        [
            15 * 60,
            25 * 60,
            45 * 60,
            60 * 60,
            90 * 60,
        ]
    }

    private func startFocusFromTaskListSection(
        _ section: HomeTaskListPresentationSection<HomeFeature.RoutineDisplay>,
        duration: TimeInterval
    ) {
        guard areMacHomeSectionFocusTimersEnabled, section.canStartFocusTimer else { return }

        do {
            _ = try FocusSessionSupport.startUnassignedFocus(
                plannedDurationSeconds: duration,
                context: modelContext
            )
            macHomeDetailMode = .planner
            taskDetailPanePlacement = nil
        } catch {
            RoutinaLog.error("Failed to start section focus: \(error.localizedDescription)")
        }
    }

    private func startFocusFromTaskListGroup(
        _ group: HomeTaskListPresentationTaskGroup<HomeFeature.RoutineDisplay>,
        duration: TimeInterval
    ) {
        guard areMacHomeSectionFocusTimersEnabled, group.canStartFocusTimer else { return }

        do {
            _ = try FocusSessionSupport.startUnassignedFocus(
                plannedDurationSeconds: duration,
                context: modelContext
            )
            macHomeDetailMode = .planner
            taskDetailPanePlacement = nil
        } catch {
            RoutinaLog.error("Failed to start group focus: \(error.localizedDescription)")
        }
    }

}

private extension HomeTaskListPresentationSection where Display == HomeFeature.RoutineDisplay {
    var canStartFocusTimer: Bool {
        guard !tasks.isEmpty else { return false }
        switch kind {
        case .plannedToday, .plannedTomorrow, .custom, .daily, .future, .tag, .untagged, .regular, .deadlineDate, .pinned:
            return true
        case .away, .archived:
            return false
        }
    }
}

private extension HomeTaskListPresentationTaskGroup where Display == HomeFeature.RoutineDisplay {
    var canStartFocusTimer: Bool {
        !tasks.isEmpty
    }
}
