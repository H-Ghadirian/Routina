import AppKit
import ComposableArchitecture
import SwiftUI

struct HomeMacHomeToolbarContent: ToolbarContent {
    enum Mode {
        case board
        case goals
        case standard
    }

    let mode: Mode
    let showsProgressModePicker: Bool
    let showsPlaces: Bool
    @Binding var progressMode: MacHomeProgressMode
    @Binding var selectedSidebarMode: HomeFeature.MacSidebarMode
    let locationSnapshot: LocationSnapshot
    @Binding var searchText: String
    let isCreatingSearchTask: Bool
    let hasHomeFiltersApplied: Bool
    let isHomeFilterDetailPresented: Bool
    let focusStartTaskCount: Int
    let activePlanFocusSession: FocusSession?
    let isPlanFocusStartDisabled: Bool
    let onPlaceCheckInMapRequested: () -> Void
    let onToggleHomeFilters: () -> Void
    let onAddEvent: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onAddGoal: () -> Void
    let onAddTask: () -> Void
    let onCheckIn: () -> Void
    let onStartAway: () -> Void
    let onSearchSubmit: (String) -> Void
    let onTaskFocusDurationSelected: (TimeInterval) -> Void
    let onPausePlanFocus: (FocusSession) -> Void
    let onResumePlanFocus: (FocusSession) -> Void
    let onFinishPlanFocus: (FocusSession) -> Void
    let onAbandonPlanFocus: (FocusSession) -> Void

    var body: some ToolbarContent {
        switch mode {
        case .board:
            boardToolbar
        case .goals:
            goalsToolbar
        case .standard:
            standardToolbar
        }
    }

    @ToolbarContentBuilder
    private var boardToolbar: some ToolbarContent {
        searchToolbarItem
        navigationToolbarItems
        progressModeToolbarItem
    }

    @ToolbarContentBuilder
    private var goalsToolbar: some ToolbarContent {
        searchToolbarItem
        navigationToolbarItems
    }

    @ToolbarContentBuilder
    private var standardToolbar: some ToolbarContent {
        searchToolbarItem
        navigationToolbarItems
        progressModeToolbarItem
    }

    @ToolbarContentBuilder
    private var searchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HomeMacToolbarSearchField(
                text: $searchText,
                isCreatingTask: isCreatingSearchTask,
                onSubmit: onSearchSubmit
            )
        }
    }

    @ToolbarContentBuilder
    private var navigationToolbarItems: some ToolbarContent {
        if showsPlaces {
            RoutinaMacPlaceCheckInToolbarItem(
                locationSnapshot: locationSnapshot,
                onMapRequested: onPlaceCheckInMapRequested
            )
        }

        ToolbarItem(placement: .navigation) {
            HomeMacToolbarFilterButton(
                hasActiveFilters: hasHomeFiltersApplied,
                isPresented: isHomeFilterDetailPresented,
                onToggle: onToggleHomeFilters
            )
        }

        if let activePlanFocusSession {
            ToolbarItem(placement: .navigation) {
                HomeMacActivePlanFocusToolbarButton(
                    session: activePlanFocusSession,
                    onPause: onPausePlanFocus,
                    onResume: onResumePlanFocus,
                    onFinish: onFinishPlanFocus,
                    onAbandon: onAbandonPlanFocus
                )
            }
        } else if isPlanFocusStartDisabled {
            RoutinaMacFocusTimerToolbarItem(hiddenKinds: [.unassigned])
        } else if focusStartTaskCount > 0 {
            ToolbarItem(placement: .navigation) {
                HomeMacPlanFocusToolbarButton(
                    focusStartTaskCount: focusStartTaskCount,
                    isDisabled: isPlanFocusStartDisabled,
                    onTaskFocusDurationSelected: onTaskFocusDurationSelected
                )
            }
        }

        ToolbarItem(placement: .navigation) {
            HomeMacSidebarModeStripView(
                selectedMode: $selectedSidebarMode,
                presentationStyle: .toolbar,
                onAddEvent: onAddEvent,
                onAddEmotion: onAddEmotion,
                onAddNote: onAddNote,
                onAddGoal: onAddGoal,
                onAddTask: onAddTask,
                onCheckIn: onCheckIn,
                onStartAway: onStartAway
            )
        }
    }

    @ToolbarContentBuilder
    private var progressModeToolbarItem: some ToolbarContent {
        if showsProgressModePicker {
            ToolbarItem(placement: .navigation) {
                MacHomeProgressModePicker(selection: $progressMode)
            }
        }
    }
}

private struct HomeMacToolbarSearchField: View {
    private enum Layout {
        static let width: CGFloat = 760
        static let height: CGFloat = 44
    }

    @Binding var text: String
    let isCreatingTask: Bool
    let onSubmit: (String) -> Void

    var body: some View {
        HomeMacToolbarSearchTextField(
            placeholder: "Search tasks and timeline",
            text: $text,
            isCreatingTask: isCreatingTask,
            onSubmit: onSubmit
        )
        .frame(width: Layout.width, height: Layout.height)
        .help("Search tasks and timeline, or create a task when there are no results")
        .accessibilityLabel("Search tasks and timeline, or create a task")
    }
}

private struct HomeMacToolbarFilterButton: View {
    let hasActiveFilters: Bool
    let isPresented: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isPresented || hasActiveFilters ? Color.accentColor : Color.secondary)
                .frame(width: 30, height: 28)
                .background {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isPresented ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.07))
                }
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filters")
        .help("Filters")
    }
}

private struct HomeMacToolbarSearchTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let isCreatingTask: Bool
    let onSubmit: (String) -> Void

    @MainActor
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: HomeMacToolbarSearchTextField
        weak var searchField: NSSearchField?
        private var shouldRestoreFocus = false
        private var focusGeneration = 0
        private var isFocusObserverInstalled = false

        init(parent: HomeMacToolbarSearchTextField) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func installFocusObserver() {
            guard !isFocusObserverInstalled else { return }
            isFocusObserverInstalled = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(focusSearchOrCreate),
                name: .routinaMacFocusSearchOrCreate,
                object: nil
            )
        }

        @objc private func focusSearchOrCreate() {
            focusSearchField(selectingText: true)
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            syncSearchText(from: notification.object)
        }

        func controlTextDidChange(_ notification: Notification) {
            syncSearchText(from: notification.object)
            restoreFocusAfterSearchUpdate()
        }

        @objc func searchAction(_ sender: NSSearchField) {
            syncSearchText(from: sender)
            restoreFocusAfterSearchUpdate()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }

            syncSearchText(from: control)
            guard !parent.isCreatingTask else { return true }
            parent.onSubmit((control as? NSTextField)?.stringValue ?? parent.text)
            restoreFocusAfterSearchUpdate()
            return true
        }

        private func syncSearchText(from object: Any?) {
            guard let textField = object as? NSTextField else { return }
            let nextText = textField.stringValue
            if parent.text != nextText {
                parent.text = nextText
            }
        }

        private func restoreFocusAfterSearchUpdate() {
            guard let searchField else { return }

            shouldRestoreFocus = true
            focusGeneration += 1
            let generation = focusGeneration
            let delays: [TimeInterval] = [0, 0.02, 0.08]
            for (index, delay) in delays.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak searchField] in
                    guard let self,
                          self.shouldRestoreFocus,
                          self.focusGeneration == generation,
                          let searchField,
                          let window = searchField.window else {
                        return
                    }

                    if self.shouldLeaveCurrentTextEditorFocused(searchField, in: window) {
                        self.shouldRestoreFocus = false
                        return
                    }

                    if window.firstResponder !== searchField.currentEditor() {
                        window.makeFirstResponder(searchField)
                    }
                    searchField.currentEditor()?.selectedRange = NSRange(
                        location: searchField.stringValue.count,
                        length: 0
                    )

                    if index == delays.indices.last {
                        self.shouldRestoreFocus = false
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, self.focusGeneration == generation else { return }
                self.shouldRestoreFocus = false
            }
        }

        private func focusSearchField(selectingText: Bool) {
            guard let searchField,
                  let window = searchField.window else { return }

            window.makeFirstResponder(searchField)
            let length = searchField.stringValue.count
            searchField.currentEditor()?.selectedRange = NSRange(
                location: selectingText ? 0 : length,
                length: selectingText ? length : 0
            )
        }

        private func shouldLeaveCurrentTextEditorFocused(
            _ searchField: NSSearchField,
            in window: NSWindow
        ) -> Bool {
            guard let activeEditor = window.firstResponder as? NSTextView else {
                return false
            }

            return activeEditor !== searchField.currentEditor()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(string: text)
        searchField.placeholderString = placeholder
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.searchAction(_:))
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.controlSize = .large
        searchField.font = NSFont.systemFont(
            ofSize: NSFont.systemFontSize(for: .large),
            weight: .semibold
        )
        searchField.focusRingType = .none
        searchField.toolTip = "Search all tasks and timeline"
        context.coordinator.searchField = searchField
        context.coordinator.installFocusObserver()
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.searchField = nsView
        nsView.placeholderString = placeholder
        nsView.toolTip = "Search tasks and timeline, or create a task when there are no results"
        nsView.controlSize = .large
        nsView.focusRingType = .none
        nsView.font = NSFont.systemFont(
            ofSize: NSFont.systemFontSize(for: .large),
            weight: .semibold
        )

        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
}

private struct HomeMacActivePlanFocusToolbarButton: View {
    let session: FocusSession
    let onPause: (FocusSession) -> Void
    let onResume: (FocusSession) -> Void
    let onFinish: (FocusSession) -> Void
    let onAbandon: (FocusSession) -> Void

    var body: some View {
        Menu {
            Button {
                if session.isPaused {
                    onResume(session)
                } else {
                    onPause(session)
                }
            } label: {
                Label(session.isPaused ? "Resume" : "Pause", systemImage: session.isPaused ? "play.fill" : "pause.fill")
            }

            Button {
                onFinish(session)
            } label: {
                Label("Finish", systemImage: "checkmark.circle.fill")
            }

            Divider()

            Button(role: .destructive) {
                onAbandon(session)
            } label: {
                Label("Abandon", systemImage: "xmark.circle")
            }
        } label: {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                planFocusToolbarLabel {
                    Image(systemName: session.isPaused ? "pause.fill" : "stopwatch.fill")
                        .font(.caption.weight(.semibold))

                    Text(activeTimeText(at: context.date))
                        .font(.caption.monospacedDigit().weight(.semibold))

                    Text(activeStatusText(at: context.date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: true, vertical: false)
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .controlSize(.small)
        .help("Start Focus Timer running")
        .padding(.trailing, 8)
    }

    private func activeTimeText(at date: Date) -> String {
        let elapsedSeconds = session.activeDurationSeconds(at: date)
        guard session.plannedDurationSeconds > 0 else {
            return FocusSessionFormatting.durationText(seconds: elapsedSeconds)
        }
        return FocusSessionFormatting.durationText(
            seconds: max(0, session.plannedDurationSeconds - elapsedSeconds)
        )
    }

    private func activeStatusText(at date: Date) -> String {
        if session.isPaused {
            return "paused"
        }
        if session.plannedDurationSeconds > 0,
           session.activeDurationSeconds(at: date) > session.plannedDurationSeconds {
            return "overtime"
        }
        return session.plannedDurationSeconds > 0 ? "left" : "elapsed"
    }
}

private struct HomeMacPlanFocusToolbarButton: View {
    let focusStartTaskCount: Int
    let isDisabled: Bool
    let onTaskFocusDurationSelected: (TimeInterval) -> Void

    private let durationOptions: [TimeInterval] = [
        15 * 60,
        25 * 60,
        45 * 60,
        60 * 60,
        90 * 60,
    ]

    var body: some View {
        Menu {
            Button {
                onTaskFocusDurationSelected(0)
            } label: {
                Label("Count up", systemImage: "stopwatch")
            }

            Divider()

            ForEach(durationOptions, id: \.self) { duration in
                Button(FocusSessionFormatting.compactDurationText(seconds: duration)) {
                    onTaskFocusDurationSelected(duration)
                }
            }
        } label: {
            planFocusToolbarLabel {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.semibold))

                Text("Focus")
                    .font(.caption.weight(.semibold))
            }
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .controlSize(.small)
        .disabled(isDisabled)
        .help(planFocusHelpTitle)
        .padding(.trailing, 8)
    }

    private var planFocusHelpTitle: String {
        let taskText = focusStartTaskCount == 1 ? "1 task" : "\(focusStartTaskCount) tasks"
        return isDisabled ? "Stop the active focus timer before starting another focus timer" : "Start Focus Timer for \(taskText)"
    }
}

@MainActor
private func planFocusToolbarLabel<Content: View>(
    @ViewBuilder content: () -> Content
) -> some View {
    HStack(spacing: 6) {
        content()
    }
    .foregroundStyle(.orange)
    .padding(.horizontal, 12)
    .frame(height: 28)
    .routinaGlassPill(tint: .orange, tintOpacity: 0.12, interactive: true)
    .overlay(
        Capsule(style: .continuous)
            .stroke(Color.orange.opacity(0.22), lineWidth: 0.75)
    )
    .contentShape(Capsule(style: .continuous))
    .fixedSize(horizontal: true, vertical: false)
}

struct HomeMacBoardInspectorToolbarButton: View {
    let isPresented: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: isPresented ? "Hide Board Details" : "Show Board Details",
            systemImage: "sidebar.right"
        ) {
            onToggle()
        }
        .help(isPresented ? "Hide board details" : "Show board details")
    }
}
