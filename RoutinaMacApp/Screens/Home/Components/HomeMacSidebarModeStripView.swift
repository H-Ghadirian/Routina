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

                Button {
                    onAddEmotion()
                } label: {
                    addMenuLabel(for: .emotion)
                }
            }

            Button {
                onAddNote()
            } label: {
                addMenuLabel(for: .note)
            }

            if isGoalsTabEnabled {
                Button {
                    onAddGoal()
                } label: {
                    addMenuLabel(for: .goal)
                }
            }
            Button {
                onAddTask()
            } label: {
                addMenuLabel(for: .task)
            }

            Divider()

            Button {
                onCheckIn()
            } label: {
                addMenuLabel(for: .checkIn)
            }

            Button {
                onStartAway()
            } label: {
                addMenuLabel(for: .away)
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
        Label {
            HStack(spacing: 22) {
                Text(shortcut.title)
                    .frame(minWidth: 68, alignment: .leading)

                Text(shortcut.shortcutTitle)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        } icon: {
            Image(systemName: shortcut.systemImage)
        }
    }

    private var helpLabelForAddMenu: String {
        let personalActions = areMacEventEmotionActionsEnabled ? "event, emotion, note" : "note"
        if isGoalsTabEnabled {
            return "Add \(personalActions), goal, task, check in, or away"
        }
        return "Add \(personalActions), task, check in, or away"
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
