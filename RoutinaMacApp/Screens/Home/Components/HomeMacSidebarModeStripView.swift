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
        HStack(spacing: 8) {
            workspaceMenu
            addControl
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var workspaceMenu: some View {
        Menu {
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Workspace: \(selectedMode.workspaceTitle)")
        .help("Switch workspace")
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

    private var addControl: some View {
        addOptionsMenu
    }

    private var addOptionsMenu: some View {
        Menu {
            ForEach(visibleAddMenuShortcuts) { shortcut in
                if shortcut == .checkIn {
                    Divider()
                }

                Button {
                    performAddMenuAction(shortcut)
                } label: {
                    Label(shortcut.menuTitle, systemImage: shortcut.systemImage)
                }
                .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
                .disabled(shortcut == .focus && focusAvailability.isDisabled)
                .help(shortcut == .focus ? focusAvailability.helpText : shortcut.detail)
            }
        } label: {
            addControlLabel
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("New")
        .help(helpLabelForAddMenu)
    }

    private var addControlLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
                .background {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                }

            Text("New")
                .font(.caption.weight(.semibold))
                .lineLimit(1)

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .frame(height: 32)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .routinaGlassPanel(
            cornerRadius: 10,
            tint: .accentColor,
            tintOpacity: 0.11,
            interactive: true
        )
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

    private var helpLabelForAddMenu: String {
        let personalActions: [String] = [
            areMacEventEmotionActionsEnabled ? "event" : nil,
            areMacEventEmotionActionsEnabled ? "emotion" : nil,
            isNotesEnabled ? "note" : nil
        ].compactMap { $0 }
        let placeAction = isPlacesEnabled ? ", check in" : ""
        let awayAction = isAwayEnabled ? ", or away" : ""
        let personalPrefix = personalActions.isEmpty ? "" : "\(personalActions.joined(separator: ", ")), "
        if isGoalsTabEnabled {
            return "Add \(personalPrefix)goal or task, or start Focus\(placeAction)\(awayAction)"
        }
        return "Add \(personalPrefix)task or start Focus\(placeAction)\(awayAction)"
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
