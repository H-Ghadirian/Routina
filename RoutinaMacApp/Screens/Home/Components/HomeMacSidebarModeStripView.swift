import SwiftUI

struct HomeMacWorkspaceToolbarControls: View {
    @Binding var selectedMode: HomeFeature.MacSidebarMode
    let onOpenSettings: () -> Void
    let onAddEvent: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onAddGoal: () -> Void
    let onAddTask: () -> Void
    let onFocus: () -> Void
    let focusAvailability: MacFocusMenuAvailability
    let onCheckIn: () -> Void
    let onStartAway: () -> Void

    @AppStorage(
        UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isGoalsTabEnabled = false
    @AppStorage(
        UserDefaultBoolValueKey.appSettingAdventureMapEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isAdventureMapEnabled = false
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
    @AppStorage(
        UserDefaultBoolValueKey.appSettingMacEventEmotionActionsEnabled.rawValue,
        store: SharedDefaults.app
    ) private var areMacEventEmotionActionsEnabled = false

    var body: some View {
        Menu {
            ForEach(combinedMenuShortcuts) { shortcut in
                Button {
                    performAddMenuAction(shortcut)
                } label: {
                    Label(shortcut.menuTitle, systemImage: shortcut.systemImage)
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
                .disabled(shortcut == .focus && focusAvailability.isDisabled)
                .help(shortcut == .focus ? focusAvailability.helpText : shortcut.detail)

                if shortcut == .focus && focusAvailability.hasActiveTimer {
                    Button {} label: {
                        Label("Another timer is running", systemImage: "info.circle")
                    }
                    .disabled(true)
                }
            }

            Divider()

            ForEach(availableWorkspaceModes) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label {
                        Text(mode.workspaceTitle)
                    } icon: {
                        Image(systemName: mode == selectedMode ? "checkmark" : mode.workspaceSystemImage)
                    }
                }
            }

            Divider()

            Button(action: onOpenSettings) {
                Label("Settings…", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
        } label: {
            combinedMenuLabel
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Workspace and actions: \(selectedMode.workspaceTitle)")
        .help("Switch workspace or choose an action")
    }

    private var combinedMenuLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: selectedMode.workspaceSystemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(selectedMode.workspaceTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .routinaGlassPanel(
            cornerRadius: 10,
            tint: .secondary,
            tintOpacity: 0.10,
            interactive: true
        )
    }

    private var availableWorkspaceModes: [HomeFeature.MacSidebarMode] {
        HomeFeature.MacSidebarMode.workspaceModes.filter { mode in
            switch mode {
            case .goals:
                return isGoalsTabEnabled
            case .adventure:
                return isAdventureMapEnabled
            default:
                return true
            }
        }
    }

    private var visibleAddMenuShortcuts: [MacAddMenuShortcut] {
        MacAddMenuShortcut.visibleActions(
            eventEmotionEnabled: areMacEventEmotionActionsEnabled,
            notesEnabled: isNotesEnabled,
            goalsEnabled: isGoalsTabEnabled,
            placesEnabled: isPlacesEnabled,
            awayEnabled: isAwayEnabled
        )
    }

    private var combinedMenuShortcuts: [MacAddMenuShortcut] {
        MacAddMenuShortcut.combinedMenuActions(from: visibleAddMenuShortcuts)
    }

    private func performAddMenuAction(_ shortcut: MacAddMenuShortcut) {
        switch shortcut {
        case .event:
            onAddEvent()
        case .emotion:
            onAddEmotion()
        case .note:
            onAddNote()
        case .goal:
            onAddGoal()
        case .task:
            onAddTask()
        case .focus:
            onFocus()
        case .checkIn:
            onCheckIn()
        case .away:
            onStartAway()
        }
    }
}

extension HomeFeature.MacSidebarMode {
    var workspaceTitle: String {
        switch self {
        case .routines:
            return "Planner"
        case .addTask:
            return "New Task"
        default:
            return rawValue
        }
    }

    var workspaceSystemImage: String {
        switch self {
        case .routines: return "calendar"
        case .board: return "square.grid.3x3.topleft.filled"
        case .goals: return "target"
        case .adventure: return "map.fill"
        case .timeline: return "clock.arrow.circlepath"
        case .stats: return "chart.bar.xaxis"
        case .backlog: return "tray.full"
        case .taskLadder: return "list.number"
        case .settings: return "gearshape"
        case .addTask: return "plus"
        }
    }
}
