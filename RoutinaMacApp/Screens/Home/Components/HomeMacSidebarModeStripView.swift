import SwiftUI

struct HomeMacSidebarModeStripView: View {
    @Binding var selectedMode: HomeFeature.MacSidebarMode
    let onAddEvent: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onAddGoal: () -> Void
    let onAddTask: () -> Void
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
        HStack(spacing: 0) {
            ForEach(displayedSidebarStripModes) { mode in
                if mode == .addTask {
                    addMenu
                } else {
                    Button {
                        selectedMode = mode
                    } label: {
                        sidebarModeLabel(for: mode)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(mode.sidebarStripTitle)
                    .help(mode.sidebarStripTitle)
                }

                if mode == .settings {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                        .padding(.vertical, 8)
                }
            }
        }
        .frame(height: 42)
        .padding(4)
        .routinaGlassPanel(cornerRadius: 13, tint: .secondary, tintOpacity: 0.10)
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var displayedSidebarStripModes: [HomeFeature.MacSidebarMode] {
        if isGoalsTabEnabled && isAdventureMapEnabled {
            return HomeFeature.MacSidebarMode.sidebarStripModes
        }
        if isGoalsTabEnabled {
            return HomeFeature.MacSidebarMode.sidebarStripModes.filter { $0 != .adventure }
        }
        if isAdventureMapEnabled {
            return HomeFeature.MacSidebarMode.sidebarStripModes.filter { $0 != .goals }
        }
        return HomeFeature.MacSidebarMode.sidebarStripModes.filter { $0 != .goals && $0 != .adventure }
    }

    private var addMenu: some View {
        Menu {
            if areMacEventEmotionActionsEnabled {
                Button {
                    onAddEvent()
                } label: {
                    addMenuLabel(for: .event)
                }
                .keyboardShortcut(
                    MacAddMenuShortcut.event.keyEquivalent,
                    modifiers: MacAddMenuShortcut.event.modifiers
                )

                Button {
                    onAddEmotion()
                } label: {
                    addMenuLabel(for: .emotion)
                }
                .keyboardShortcut(
                    MacAddMenuShortcut.emotion.keyEquivalent,
                    modifiers: MacAddMenuShortcut.emotion.modifiers
                )
            }

            if isNotesEnabled {
                Button {
                    onAddNote()
                } label: {
                    addMenuLabel(for: .note)
                }
                .keyboardShortcut(
                    MacAddMenuShortcut.note.keyEquivalent,
                    modifiers: MacAddMenuShortcut.note.modifiers
                )
            }

            if isGoalsTabEnabled {
                Button {
                    onAddGoal()
                } label: {
                    addMenuLabel(for: .goal)
                }
                .keyboardShortcut(
                    MacAddMenuShortcut.goal.keyEquivalent,
                    modifiers: MacAddMenuShortcut.goal.modifiers
                )
            }
            Button {
                onAddTask()
            } label: {
                addMenuLabel(for: .task)
            }
            .keyboardShortcut(
                MacAddMenuShortcut.task.keyEquivalent,
                modifiers: MacAddMenuShortcut.task.modifiers
            )

            if isPlacesEnabled {
                Divider()

                Button {
                    onCheckIn()
                } label: {
                    addMenuLabel(for: .checkIn)
                }
                .keyboardShortcut(
                    MacAddMenuShortcut.checkIn.keyEquivalent,
                    modifiers: MacAddMenuShortcut.checkIn.modifiers
                )
            }

            if isAwayEnabled {
                Button {
                    onStartAway()
                } label: {
                    addMenuLabel(for: .away)
                }
                .keyboardShortcut(
                    MacAddMenuShortcut.away.keyEquivalent,
                    modifiers: MacAddMenuShortcut.away.modifiers
                )
            }
        } label: {
            sidebarModeLabel(for: .addTask)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Add")
            .help(
                helpLabelForAddMenu
            )
    }

    private func addMenuLabel(for shortcut: MacAddMenuShortcut) -> some View {
        Label(shortcut.title, systemImage: shortcut.systemImage)
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
            return "Add \(personalPrefix)goal, task\(placeAction)\(awayAction)"
        }
        return "Add \(personalPrefix)task\(placeAction)\(awayAction)"
    }

    private func sidebarModeLabel(for mode: HomeFeature.MacSidebarMode) -> some View {
        let isSelected = selectedMode == mode
        let isAddTab = mode == .addTask

        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.clear)
                .routinaIf(isSelected) { view in
                    view.routinaGlassCard(
                        cornerRadius: 10,
                        tint: .accentColor,
                        tintOpacity: 0.42,
                        interactive: true
                    )
                }

            Image(systemName: sidebarModeIcon(for: mode))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    isSelected ? Color.white : (isAddTab ? Color.accentColor : Color.secondary)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func sidebarModeIcon(for mode: HomeFeature.MacSidebarMode) -> String {
        switch mode {
        case .routines: return "checklist"
        case .board: return "square.grid.3x3.topleft.filled"
        case .goals: return "target"
        case .adventure: return "map.fill"
        case .timeline: return "clock.arrow.circlepath"
        case .stats: return "chart.bar.xaxis"
        case .settings: return "gearshape"
        case .addTask: return "plus"
        }
    }
}
