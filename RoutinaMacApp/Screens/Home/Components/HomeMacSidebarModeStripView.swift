import SwiftUI

struct HomeMacSidebarModeStripView: View {
    enum PresentationStyle {
        case sidebar
        case toolbar

        var height: CGFloat {
            switch self {
            case .sidebar: return 42
            case .toolbar: return 28
            }
        }

        var padding: CGFloat {
            switch self {
            case .sidebar: return 4
            case .toolbar: return 2
            }
        }

        var cornerRadius: CGFloat {
            switch self {
            case .sidebar: return 13
            case .toolbar: return 9
            }
        }

        var selectedCornerRadius: CGFloat {
            switch self {
            case .sidebar: return 10
            case .toolbar: return 7
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .sidebar: return 15
            case .toolbar: return 12
            }
        }

        var segmentWidth: CGFloat? {
            switch self {
            case .sidebar: return nil
            case .toolbar: return 26
            }
        }

        var separatorVerticalPadding: CGFloat {
            switch self {
            case .sidebar: return 8
            case .toolbar: return 5
            }
        }
    }

    @Binding var selectedMode: HomeFeature.MacSidebarMode
    let presentationStyle: PresentationStyle
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

    init(
        selectedMode: Binding<HomeFeature.MacSidebarMode>,
        presentationStyle: PresentationStyle = .sidebar,
        onAddEvent: @escaping () -> Void,
        onAddEmotion: @escaping () -> Void,
        onAddNote: @escaping () -> Void,
        onAddGoal: @escaping () -> Void,
        onAddTask: @escaping () -> Void,
        onCheckIn: @escaping () -> Void,
        onStartAway: @escaping () -> Void
    ) {
        self._selectedMode = selectedMode
        self.presentationStyle = presentationStyle
        self.onAddEvent = onAddEvent
        self.onAddEmotion = onAddEmotion
        self.onAddNote = onAddNote
        self.onAddGoal = onAddGoal
        self.onAddTask = onAddTask
        self.onCheckIn = onCheckIn
        self.onStartAway = onStartAway
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(displayedSidebarStripModes) { mode in
                if mode == .addTask {
                    addControl
                } else {
                    Button {
                        selectedMode = mode
                    } label: {
                        sidebarModeLabel(for: mode)
                    }
                    .buttonStyle(.plain)
                    .modeStripItemFrame(presentationStyle)
                    .accessibilityLabel(mode.sidebarStripTitle)
                    .help(mode.sidebarStripTitle)
                }

                if mode == .settings {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1)
                        .padding(.vertical, presentationStyle.separatorVerticalPadding)
                }
            }
        }
        .frame(height: presentationStyle.height)
        .padding(presentationStyle.padding)
        .routinaGlassPanel(
            cornerRadius: presentationStyle.cornerRadius,
            tint: .secondary,
            tintOpacity: 0.10
        )
        .overlay(
            RoundedRectangle(cornerRadius: presentationStyle.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .fixedSize(horizontal: presentationStyle == .toolbar, vertical: false)
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

    @ViewBuilder
    private var addControl: some View {
        if let shortcut = onlyVisibleAddMenuShortcut {
            Button {
                performAddMenuAction(shortcut)
            } label: {
                sidebarModeLabel(for: .addTask)
            }
            .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
            .buttonStyle(.plain)
            .modeStripItemFrame(presentationStyle)
            .accessibilityLabel(shortcut.commandTitle)
            .help(shortcut.commandTitle)
        } else {
            addOptionsMenu
        }
    }

    private var addOptionsMenu: some View {
        Menu {
            ForEach(visibleAddMenuShortcuts) { shortcut in
                if shortcut == .checkIn {
                    Divider()
                }
                addMenuButton(for: shortcut)
            }
        } label: {
            sidebarModeLabel(for: .addTask)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .modeStripItemFrame(presentationStyle)
        .accessibilityLabel("Add")
        .help(helpLabelForAddMenu)
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

    private var onlyVisibleAddMenuShortcut: MacAddMenuShortcut? {
        let shortcuts = visibleAddMenuShortcuts
        return shortcuts.count == 1 ? shortcuts[0] : nil
    }

    private func addMenuButton(for shortcut: MacAddMenuShortcut) -> some View {
        Button {
            performAddMenuAction(shortcut)
        } label: {
            addMenuLabel(for: shortcut)
        }
        .keyboardShortcut(shortcut.keyEquivalent, modifiers: shortcut.modifiers)
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
        case .checkIn:
            onCheckIn()
        case .away:
            onStartAway()
        }
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
            RoundedRectangle(cornerRadius: presentationStyle.selectedCornerRadius, style: .continuous)
                .fill(Color.clear)
                .routinaIf(isSelected) { view in
                    view.routinaGlassCard(
                        cornerRadius: presentationStyle.selectedCornerRadius,
                        tint: .accentColor,
                        tintOpacity: 0.42,
                        interactive: true
                    )
                }

            Image(systemName: sidebarModeIcon(for: mode))
                .font(.system(size: presentationStyle.iconSize, weight: .semibold))
                .foregroundStyle(
                    isSelected ? Color.white : (isAddTab ? Color.accentColor : Color.secondary)
                )
        }
        .modeStripLabelFrame(presentationStyle)
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

private extension View {
    @ViewBuilder
    func modeStripItemFrame(
        _ presentationStyle: HomeMacSidebarModeStripView.PresentationStyle
    ) -> some View {
        switch presentationStyle {
        case .sidebar:
            frame(maxWidth: .infinity)
        case .toolbar:
            frame(width: presentationStyle.segmentWidth)
        }
    }

    @ViewBuilder
    func modeStripLabelFrame(
        _ presentationStyle: HomeMacSidebarModeStripView.PresentationStyle
    ) -> some View {
        switch presentationStyle {
        case .sidebar:
            frame(maxWidth: .infinity, maxHeight: .infinity)
        case .toolbar:
            frame(width: presentationStyle.segmentWidth)
                .frame(maxHeight: .infinity)
        }
    }
}
