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
    let canCreateSearchTask: Bool
    let focusStartTaskCount: Int
    let activePlanFocusSession: FocusSession?
    let isPlanFocusStartDisabled: Bool
    let onPlaceCheckInMapRequested: () -> Void
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
                canCreateTaskFromQuery: canCreateSearchTask,
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

enum HomeMacToolbarSearchLayout {
    static let width: CGFloat = 760
    static let height: CGFloat = 44
    static let parserPreviewTopPadding: CGFloat = 12
    static let parserPreviewTrailingPadding: CGFloat = 22
}

private struct HomeMacToolbarSearchField: View {
    @Binding var text: String
    let isCreatingTask: Bool
    let canCreateTaskFromQuery: Bool
    let onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            HomeMacToolbarSearchTextField(
                placeholder: HomeMacToolbarSearchCopy.placeholder,
                text: $text,
                isCreatingTask: isCreatingTask,
                onSubmit: onSubmit
            )
            .frame(maxWidth: .infinity, maxHeight: HomeMacToolbarSearchLayout.height)

            if showsCreateHint {
                createHint
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .frame(width: HomeMacToolbarSearchLayout.width, height: HomeMacToolbarSearchLayout.height)
        .animation(.easeOut(duration: 0.12), value: showsCreateHint)
        .help(HomeMacToolbarSearchCopy.help)
        .accessibilityLabel(HomeMacToolbarSearchCopy.accessibilityLabel)
    }

    private var showsCreateHint: Bool {
        isCreatingTask || canCreateTaskFromQuery
    }

    private var createHint: some View {
        HStack(spacing: 6) {
            if isCreatingTask {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.72)

                Text(HomeMacToolbarSearchCopy.creatingHint)
            } else {
                Text(HomeMacToolbarSearchCopy.returnKeyHint)
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .background {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.secondary.opacity(0.14))
                    }

                Text(HomeMacToolbarSearchCopy.createHint)
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isCreatingTask ? Color.accentColor : Color.secondary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background {
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        }
        .overlay {
            Capsule(style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

struct HomeMacToolbarSearchParserPreview: View {
    @Environment(\.calendar) private var calendar
    let draft: RoutinaQuickAddDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(HomeMacToolbarSearchCopy.parserPreviewTitle, systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "textformat")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 16)

                Text(draft.name)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(parsedRows) { row in
                    parsedRow(row)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.96))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }

    private var parsedRows: [ParsedRow] {
        var rows: [ParsedRow] = []

        if draft.scheduleMode != .oneOff {
            rows.append(ParsedRow(
                title: draft.scheduleMode.isSoftIntervalRoutine ? "Gentle routine" : "Repeats",
                value: draft.recurrenceRule.displayText(calendar: calendar),
                systemImage: "calendar"
            ))
        } else if let deadline = draft.deadline {
            rows.append(ParsedRow(
                title: "Due",
                value: deadline.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            ))
        }

        if !draft.tags.isEmpty {
            rows.append(ParsedRow(
                title: "Tags",
                value: draft.tags.map { "#\($0)" }.joined(separator: " "),
                systemImage: "tag"
            ))
        }

        if let placeName = draft.placeName {
            rows.append(ParsedRow(
                title: "Place",
                value: "@\(placeName)",
                systemImage: "mappin.and.ellipse"
            ))
        }

        if draft.importance != .level2 || draft.urgency != .level2 {
            rows.append(ParsedRow(
                title: "Priority",
                value: "\(draft.importance.title) / \(draft.urgency.title)",
                systemImage: "exclamationmark.triangle"
            ))
        }

        if let estimatedDurationMinutes = draft.estimatedDurationMinutes {
            rows.append(ParsedRow(
                title: "Focus",
                value: "\(estimatedDurationMinutes)m",
                systemImage: "timer"
            ))
        }

        return rows
    }

    private func parsedRow(_ row: ParsedRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: row.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 16)

            Text(row.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)

            Text(row.value)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }

    private struct ParsedRow: Identifiable {
        let title: String
        let value: String
        let systemImage: String

        var id: String { "\(title):\(value)" }
    }
}

private enum HomeMacToolbarSearchCopy {
    static let placeholder = "Search tasks and timeline, or create a task"
    static let help = "Search tasks and timeline, or press Return to create a task when there are no results"
    static let accessibilityLabel = "Search tasks and timeline, or create a task"
    static let returnKeyHint = "Return"
    static let createHint = "Create task"
    static let creatingHint = "Creating task"
    static let parserPreviewTitle = "Detected details"
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
        searchField.toolTip = HomeMacToolbarSearchCopy.help
        context.coordinator.searchField = searchField
        context.coordinator.installFocusObserver()
        return searchField
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        context.coordinator.parent = self
        context.coordinator.searchField = nsView
        nsView.placeholderString = placeholder
        nsView.toolTip = HomeMacToolbarSearchCopy.help
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
