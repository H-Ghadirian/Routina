import AppKit
import SwiftUI

struct HomeMacTopToolbarChrome: View {
    enum Mode {
        case board
        case goals
        case standard
    }

    let mode: Mode
    let doneCount: Int
    let showsDoneCount: Bool
    let isDevelopmentAppVariant: Bool
    let showsProgressModePicker: Bool
    let showsPlaces: Bool
    @Binding var progressMode: MacHomeProgressMode
    @Binding var selectedSidebarMode: HomeFeature.MacSidebarMode
    @Binding var searchText: String
    @Binding var isSearchTextFocused: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var searchVisiblePillWidth: CGFloat
    @Binding var searchExpansionTransitionID: Int
    @Binding var searchFocusRequestID: Int
    @Binding var searchFocusDismissRequestID: Int
    let isSidebarCollapsed: Bool
    let locationSnapshot: LocationSnapshot
    let onPlaceCheckInMapRequested: () -> Void
    let isCreatingTaskFromSearch: Bool
    let canCreateTaskFromSearch: Bool
    let onSearchSubmit: (String) -> Void
    let onSearchCommandSubmit: (String) -> Void
    let onAddEvent: () -> Void
    let onAddEmotion: () -> Void
    let onAddNote: () -> Void
    let onAddGoal: () -> Void
    let onAddTask: () -> Void
    let onCheckIn: () -> Void
    let onStartAway: () -> Void
    let isBoardInspectorPresented: Bool
    let onToggleBoardInspector: () -> Void
    let onToggleSidebar: () -> Void

    var body: some View {
        toolbarRow
        .frame(height: HomeMacToolbarSearchLayout.topToolbarHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .leading) {
            HomeMacSidebarVisibilityToolbarButton(
                isCollapsed: isSidebarCollapsed,
                onToggle: onToggleSidebar
            )
            .padding(.leading, HomeMacToolbarSearchLayout.sidebarToggleLeadingPadding)
        }
        .background(HomeMacToolbarSearchLayout.toolbarBackground)
        .overlay(alignment: .bottom) {
            Divider()
                .opacity(0.55)
        }
    }

    private var toolbarRow: some View {
        ZStack(alignment: .center) {
            HStack(alignment: .center, spacing: 12) {
                statusBadges
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(3)

                Spacer(minLength: 8)

                toolbarTrailingCluster
                    .layoutPriority(4)
            }
            .padding(.leading, HomeMacToolbarSearchLayout.trafficLightReservedLeadingPadding)
            .padding(.trailing, HomeMacToolbarSearchLayout.topToolbarHorizontalPadding)
            .frame(height: HomeMacToolbarSearchLayout.topToolbarHeight)
            .frame(maxWidth: .infinity)

            toolbarSearch
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: HomeMacToolbarSearchLayout.topToolbarHeight)
        .frame(maxWidth: .infinity)
    }

    private var toolbarSearch: some View {
        HomeMacToolbarSearchField(
            text: $searchText,
            isTextFocused: $isSearchTextFocused,
            isSearchExpanded: $isSearchExpanded,
            visiblePillWidth: $searchVisiblePillWidth,
            searchExpansionTransitionID: $searchExpansionTransitionID,
            focusRequestID: $searchFocusRequestID,
            focusDismissRequestID: $searchFocusDismissRequestID,
            isCreatingTask: isCreatingTaskFromSearch,
            canCreateTaskFromQuery: canCreateTaskFromSearch,
            onSubmit: onSearchSubmit,
            onCommandSubmit: onSearchCommandSubmit
        )
        .frame(width: HomeMacToolbarSearchLayout.focusedWidth, alignment: .center)
        .layoutPriority(2)
    }

    private var toolbarTrailingCluster: some View {
        HStack(spacing: 12) {
            toolbarCommandCluster

            if mode == .board {
                HomeMacBoardInspectorToolbarButton(
                    isPresented: isBoardInspectorPresented,
                    onToggle: onToggleBoardInspector
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var toolbarCommandCluster: some View {
        HStack(spacing: 10) {
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

            if showsProgressModePicker {
                MacHomeProgressModePicker(selection: $progressMode)
            }

            if showsPlaces {
                RoutinaMacPlaceCheckInToolbarButton(
                    locationSnapshot: locationSnapshot,
                    onMapRequested: onPlaceCheckInMapRequested
                )
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var statusBadges: some View {
        HStack(spacing: 8) {
            if isDevelopmentAppVariant {
                MacToolbarStatusBadge(
                    title: "Dev Version",
                    systemImage: "hammer.fill",
                    tintColor: .systemOrange
                )
                .help("Development version")
            }

            if showsDoneCount {
                MacToolbarStatusBadge(
                    title: "\(doneCount) done",
                    systemImage: "checkmark.seal.fill",
                    tintColor: .systemGreen
                )
                .help("\(doneCount) total done")
            }
        }
    }
}

private struct HomeMacSidebarVisibilityToolbarButton: View {
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        MacToolbarIconButton(
            title: title,
            systemImage: "sidebar.left"
        ) {
            onToggle()
        }
        .frame(
            width: HomeMacToolbarSearchLayout.sidebarToggleButtonSize,
            height: HomeMacToolbarSearchLayout.sidebarToggleButtonSize
        )
        .contentShape(Rectangle())
        .fixedSize()
        .help(title)
        .accessibilityLabel(title)
    }

    private var title: String {
        isCollapsed ? "Expand Sidebar" : "Collapse Sidebar"
    }
}

enum HomeMacToolbarSearchLayout {
    static let compactWidth: CGFloat = 620
    static let focusedWidth: CGFloat = 860
    static let height: CGFloat = 44
    static let cornerRadius: CGFloat = 22
    static let horizontalPadding: CGFloat = 18
    static let iconSize: CGFloat = 18
    static let textFieldHeight: CGFloat = 26
    static let clearButtonSize: CGFloat = 22
    static let createHintWidth: CGFloat = 154
    static let animationDuration: TimeInterval = 0.22
    static let toolbarActionRestoreDelay: TimeInterval = animationDuration
    static let parserPreviewTopPadding: CGFloat = 12
    static let parserPreviewTrailingPadding: CGFloat = 22
    static let topToolbarHeight: CGFloat = 62
    static let topToolbarHorizontalPadding: CGFloat = 18
    static let trafficLightReservedLeadingPadding: CGFloat = 142
    static let sidebarToggleLeadingPadding: CGFloat = 28
    static let sidebarToggleButtonSize: CGFloat = 28

    static var toolbarBackground: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.98)
    }

    static func searchBackgroundColor(isFocused: Bool) -> Color {
        if isFocused {
            Color(nsColor: .textBackgroundColor).opacity(0.98)
        } else {
            Color(nsColor: .controlBackgroundColor).opacity(0.82)
        }
    }

    static func searchStrokeColor(isFocused: Bool) -> Color {
        Color.secondary.opacity(isFocused ? 0.24 : 0.14)
    }
}

struct HomeMacToolbarSearchField: View {
    @Binding var text: String
    @Binding var isTextFocused: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var visiblePillWidth: CGFloat
    @Binding var searchExpansionTransitionID: Int
    @Binding var focusRequestID: Int
    @Binding var focusDismissRequestID: Int
    let isCreatingTask: Bool
    let canCreateTaskFromQuery: Bool
    let onSubmit: (String) -> Void
    let onCommandSubmit: (String) -> Void

    var body: some View {
        searchShell(width: visiblePillWidth)
            .frame(
                width: visiblePillWidth,
                height: HomeMacToolbarSearchLayout.height,
                alignment: .center
            )
            .allowsHitTesting(true)
            .animation(
                .easeInOut(duration: HomeMacToolbarSearchLayout.animationDuration),
                value: visiblePillWidth
            )
    }

    private func searchShell(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            searchFocusTarget(width: width)

            if usesCenteredIdleContent {
                centeredIdleContent
                    .frame(
                        width: width,
                        height: HomeMacToolbarSearchLayout.height,
                        alignment: .center
                    )
                    .transition(.opacity)
            }

            Image(systemName: "magnifyingglass")
                .font(.system(size: HomeMacToolbarSearchLayout.iconSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(
                    width: HomeMacToolbarSearchLayout.iconSize,
                    height: HomeMacToolbarSearchLayout.iconSize
                )
                .offset(x: HomeMacToolbarSearchLayout.horizontalPadding)
                .opacity(usesCenteredIdleContent ? 0 : 1)
                .allowsHitTesting(false)

            HStack(spacing: 10) {
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        placeholderLabel
                    }

                    textEditor
                }
                .layoutPriority(1)

                if !text.isEmpty {
                    clearSearchButton
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .layoutPriority(2)
                        .zIndex(2)
                }

                if showsCreateHint {
                    createHint
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        .layoutPriority(3)
                }

                if isTextFocused {
                    closeButton
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .layoutPriority(2)
                }
            }
            .padding(.leading, textLeading)
            .padding(.trailing, 12)
            .frame(width: width, height: HomeMacToolbarSearchLayout.height, alignment: .leading)
            .opacity(usesCenteredIdleContent ? 0 : 1)
            .allowsHitTesting(!usesCenteredIdleContent)
        }
        .frame(width: width, height: HomeMacToolbarSearchLayout.height)
        .background {
            RoundedRectangle(
                cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                style: .continuous
            )
            .fill(HomeMacToolbarSearchLayout.searchBackgroundColor(isFocused: isTextFocused))
        }
        .overlay {
            RoundedRectangle(
                cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                style: .continuous
            )
            .stroke(HomeMacToolbarSearchLayout.searchStrokeColor(isFocused: isTextFocused), lineWidth: 1)
        }
        .overlay {
            outsideClickDismissLayer
                .allowsHitTesting(false)
        }
        .contentShape(
            RoundedRectangle(
                cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                style: .continuous
            )
        )
        .animation(.easeOut(duration: 0.12), value: text.isEmpty)
        .animation(.easeOut(duration: 0.12), value: showsCreateHint)
        .animation(.easeOut(duration: 0.12), value: usesCenteredIdleContent)
        .help(HomeMacToolbarSearchCopy.help)
        .accessibilityLabel(HomeMacToolbarSearchCopy.accessibilityLabel)
    }

    private func searchFocusTarget(width: CGFloat) -> some View {
        Button {
            beginSearchFocusRequest()
        } label: {
            Color.clear
                .frame(width: width, height: HomeMacToolbarSearchLayout.height)
                .contentShape(
                    RoundedRectangle(
                        cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                        style: .continuous
                    )
                )
        }
        .buttonStyle(.plain)
        .frame(width: width, height: HomeMacToolbarSearchLayout.height)
        .contentShape(
            RoundedRectangle(
                cornerRadius: HomeMacToolbarSearchLayout.cornerRadius,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }

    private var outsideClickDismissLayer: some View {
        HomeMacToolbarSearchOutsideClickDismissView(
            isFocused: searchFocusBinding,
            focusRequestID: $focusRequestID,
            focusDismissRequestID: $focusDismissRequestID
        )
        .accessibilityHidden(true)
    }

    private var placeholderLabel: some View {
        Text(HomeMacToolbarSearchCopy.placeholder)
            .font(Font.body.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .allowsHitTesting(false)
    }

    private var centeredIdleContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: HomeMacToolbarSearchLayout.iconSize, weight: .medium))
                .foregroundStyle(.secondary)

            Text(HomeMacToolbarSearchCopy.placeholder)
                .font(Font.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, HomeMacToolbarSearchLayout.horizontalPadding)
        .allowsHitTesting(false)
    }

    private var textEditor: some View {
        HomeMacToolbarSearchTextField(
            text: $text,
            isCreatingTask: isCreatingTask,
            isFocused: searchFocusBinding,
            focusRequestID: focusRequestID,
            focusDismissRequestID: focusDismissRequestID,
            onSubmit: onSubmit,
            onCommandSubmit: onCommandSubmit
        )
        .frame(maxWidth: .infinity)
        .frame(height: HomeMacToolbarSearchLayout.textFieldHeight)
        .layoutPriority(1)
    }

    private var clearSearchButton: some View {
        Button {
            clearSearchText()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(
                    width: HomeMacToolbarSearchLayout.clearButtonSize,
                    height: HomeMacToolbarSearchLayout.clearButtonSize
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeMacToolbarSearchCopy.clearAccessibilityLabel)
        .help(HomeMacToolbarSearchCopy.clearHelp)
    }

    private var closeButton: some View {
        Button {
            dismissSearchFocusFromKeycap()
        } label: {
            Text("Esc")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(Color.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 34, height: 28)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.secondary.opacity(0.10))
        }
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .accessibilityLabel(HomeMacToolbarSearchCopy.closeAccessibilityLabel)
        .help(HomeMacToolbarSearchCopy.closeHelp)
    }

    private var textLeading: CGFloat {
        HomeMacToolbarSearchLayout.horizontalPadding
            + HomeMacToolbarSearchLayout.iconSize
            + 10
    }

    private var usesCenteredIdleContent: Bool {
        !isTextFocused && text.isEmpty
    }

    private var searchFocusBinding: Binding<Bool> {
        Binding(
            get: { isTextFocused },
            set: { setSearchFocused($0) }
        )
    }

    private func beginSearchFocusRequest() {
        focusRequestID += 1
        setSearchFocused(true)
    }

    private func clearSearchText() {
        text = ""
        focusRequestID += 1
        setSearchFocused(true)

        DispatchQueue.main.async {
            text = ""
            focusRequestID += 1
        }
    }

    private func dismissSearchFocusFromKeycap() {
        setSearchFocused(false)
        focusDismissRequestID += 1
    }

    private func setSearchFocused(_ nextValue: Bool) {
        if nextValue {
            searchExpansionTransitionID += 1
            let transitionID = searchExpansionTransitionID
            if !isSearchExpanded {
                visiblePillWidth = HomeMacToolbarSearchLayout.compactWidth
                isSearchExpanded = true
                DispatchQueue.main.async {
                    guard searchExpansionTransitionID == transitionID else { return }
                    animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.focusedWidth)
                }
            } else {
                animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.focusedWidth)
            }
            if !isTextFocused {
                isTextFocused = true
            }
            return
        }

        guard isTextFocused || isSearchExpanded else { return }
        isTextFocused = false
        animateVisiblePillWidth(to: HomeMacToolbarSearchLayout.compactWidth)
        let transitionID = searchExpansionTransitionID
        DispatchQueue.main.asyncAfter(deadline: .now() + HomeMacToolbarSearchLayout.toolbarActionRestoreDelay) {
            guard searchExpansionTransitionID == transitionID else { return }
            isSearchExpanded = false
        }
    }

    private func animateVisiblePillWidth(to width: CGFloat) {
        withAnimation(.easeInOut(duration: HomeMacToolbarSearchLayout.animationDuration)) {
            visiblePillWidth = width
        }
    }

    private var showsCreateHint: Bool {
        isTextFocused && (isCreatingTask || canCreateTaskFromQuery)
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
        .truncationMode(.tail)
        .padding(.horizontal, 10)
        .frame(width: HomeMacToolbarSearchLayout.createHintWidth, alignment: .leading)
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
    static let placeholder = "Search or create a task"
    static let help = "Search tasks and timeline, or press Return to create a task when there are no results"
    static let accessibilityLabel = "Search or create a task"
    static let returnKeyHint = "Return"
    static let createHint = "Create task"
    static let creatingHint = "Creating task"
    static let parserPreviewTitle = "Detected details"
    static let closeAccessibilityLabel = "Dismiss search focus"
    static let closeHelp = "Dismiss search focus"
    static let clearAccessibilityLabel = "Clear search"
    static let clearHelp = "Clear search"
}

private extension Notification.Name {
    static let routinaMacToolbarSearchDismissFocus = Notification.Name("routina.mac.toolbarSearchDismissFocus")
}

private struct HomeMacToolbarSearchOutsideClickDismissView: NSViewRepresentable {
    @Binding var isFocused: Bool
    @Binding var focusRequestID: Int
    @Binding var focusDismissRequestID: Int

    @MainActor
    final class Coordinator {
        var parent: HomeMacToolbarSearchOutsideClickDismissView
        weak var view: HomeMacToolbarSearchOutsideClickDismissNSView?
        private var mouseDownMonitor: Any?
        private var keyDownMonitor: Any?

        init(parent: HomeMacToolbarSearchOutsideClickDismissView) {
            self.parent = parent
        }

        func installMouseDownMonitorIfNeeded() {
            guard mouseDownMonitor == nil else { return }
            mouseDownMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleMouseDown(event)
                }
                return event
            }
            installKeyDownMonitorIfNeeded()
        }

        private func installKeyDownMonitorIfNeeded() {
            guard keyDownMonitor == nil else { return }
            keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                var didConsumeEvent = false
                MainActor.assumeIsolated {
                    didConsumeEvent = self?.handleKeyDown(event) ?? false
                }
                return didConsumeEvent ? nil : event
            }
        }

        private func handleMouseDown(_ event: NSEvent) {
            guard let view,
                  let window = view.window else {
                return
            }

            if clickIsInsideVisiblePill(event, in: view) {
                parent.isFocused = true
                parent.focusRequestID += 1
                return
            }

            guard parent.isFocused else { return }
            dismissFocusedSearch(in: window)
        }

        private func handleKeyDown(_ event: NSEvent) -> Bool {
            guard event.keyCode == 53,
                  parent.isFocused,
                  let window = view?.window else {
                return false
            }

            dismissFocusedSearch(in: window)
            return true
        }

        private func dismissFocusedSearch(in window: NSWindow) {
            parent.isFocused = false
            parent.focusDismissRequestID += 1
            NotificationCenter.default.post(
                name: .routinaMacToolbarSearchDismissFocus,
                object: window
            )
        }

        private func clickIsInsideVisiblePill(
            _ event: NSEvent,
            in view: HomeMacToolbarSearchOutsideClickDismissNSView
        ) -> Bool {
            guard let viewWindow = view.window,
                  let eventWindow = event.window else {
                return false
            }

            let screenLocation = eventWindow.convertPoint(toScreen: event.locationInWindow)
            let viewWindowLocation = viewWindow.convertPoint(fromScreen: screenLocation)
            let viewLocation = view.convert(viewWindowLocation, from: nil)
            return view.bounds.insetBy(dx: -2, dy: -2).contains(viewLocation)
        }

        func removeMouseDownMonitor() {
            if let mouseDownMonitor {
                NSEvent.removeMonitor(mouseDownMonitor)
            }
            if let keyDownMonitor {
                NSEvent.removeMonitor(keyDownMonitor)
            }
            self.mouseDownMonitor = nil
            self.keyDownMonitor = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HomeMacToolbarSearchOutsideClickDismissNSView {
        let view = HomeMacToolbarSearchOutsideClickDismissNSView()
        view.setPrefersIBeamCursor(isFocused)
        context.coordinator.view = view
        context.coordinator.installMouseDownMonitorIfNeeded()
        return view
    }

    func updateNSView(
        _ nsView: HomeMacToolbarSearchOutsideClickDismissNSView,
        context: Context
    ) {
        context.coordinator.parent = self
        context.coordinator.view = nsView
        nsView.setPrefersIBeamCursor(isFocused)
        context.coordinator.installMouseDownMonitorIfNeeded()
    }

    @MainActor
    static func dismantleNSView(
        _ nsView: HomeMacToolbarSearchOutsideClickDismissNSView,
        coordinator: Coordinator
    ) {
        coordinator.removeMouseDownMonitor()
    }
}

private final class HomeMacToolbarSearchOutsideClickDismissNSView: NSView {
    private var prefersIBeamCursor = false

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func setPrefersIBeamCursor(_ nextValue: Bool) {
        guard prefersIBeamCursor != nextValue else { return }
        prefersIBeamCursor = nextValue

        if let window {
            window.invalidateCursorRects(for: self)
            let pointerLocation = convert(window.mouseLocationOutsideOfEventStream, from: nil)
            if bounds.contains(pointerLocation) {
                (nextValue ? NSCursor.iBeam : NSCursor.arrow).set()
            }
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        guard prefersIBeamCursor else { return }
        addCursorRect(bounds, cursor: .iBeam)
    }
}

private struct HomeMacToolbarSearchTextField: NSViewRepresentable {
    @Binding var text: String
    let isCreatingTask: Bool
    @Binding var isFocused: Bool
    let focusRequestID: Int
    let focusDismissRequestID: Int
    let onSubmit: (String) -> Void
    let onCommandSubmit: (String) -> Void

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: HomeMacToolbarSearchTextField
        weak var textField: NSTextField?
        private var shouldRestoreFocus = false
        private var focusGeneration = 0
        private var isFocusObserverInstalled = false
        private var handledFocusRequestID: Int
        private var handledFocusDismissRequestID: Int

        init(parent: HomeMacToolbarSearchTextField) {
            self.parent = parent
            self.handledFocusRequestID = parent.focusRequestID - 1
            self.handledFocusDismissRequestID = parent.focusDismissRequestID
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
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(dismissSearchOrCreate),
                name: .routinaMacToolbarSearchDismissFocus,
                object: nil
            )
        }

        @objc private func focusSearchOrCreate() {
            focusTextField(selectingText: true)
        }

        @objc private func dismissSearchOrCreate(_ notification: Notification) {
            if let targetWindow = notification.object as? NSWindow,
               textField?.window !== targetWindow {
                return
            }
            dismissSearchFocus()
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func pointerFocusRequested() {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            syncSearchText(from: notification.object)
            guard handledFocusRequestID == parent.focusRequestID else { return }
            parent.isFocused = false
        }

        func controlTextDidChange(_ notification: Notification) {
            syncSearchText(from: notification.object)
            restoreFocusAfterSearchUpdate()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                syncSearchText(from: control)
                dismissSearchFocus()
                return true
            }

            let isCommandReturn = isCommandModifiedReturn && isNewlineCommand(commandSelector)
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) || isCommandReturn else {
                return false
            }

            syncSearchText(from: control)
            guard !parent.isCreatingTask else { return true }
            let submittedText = (control as? NSTextField)?.stringValue ?? parent.text
            if isCommandReturn {
                dismissSearchFocus()
                parent.onCommandSubmit(submittedText)
                return true
            }
            parent.onSubmit(submittedText)
            restoreFocusAfterSearchUpdate()
            return true
        }

        private func isNewlineCommand(_ commandSelector: Selector) -> Bool {
            commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
        }

        private var isCommandModifiedReturn: Bool {
            guard let event = NSApp.currentEvent else { return false }
            return event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(.command)
        }

        private func syncSearchText(from object: Any?) {
            guard let textField = object as? NSTextField else { return }
            let nextText = textField.stringValue
            if parent.text != nextText {
                parent.text = nextText
            }
        }

        func focusIfNeeded(for requestID: Int) {
            guard requestID != handledFocusRequestID else { return }
            guard parent.isFocused else {
                handledFocusRequestID = requestID
                return
            }
            guard focusTextField(selectingText: false) else { return }
            handledFocusRequestID = requestID
        }

        func dismissFocusIfNeeded(for requestID: Int) {
            guard requestID != handledFocusDismissRequestID else { return }
            handledFocusDismissRequestID = requestID
            dismissSearchFocus()
        }

        private func restoreFocusAfterSearchUpdate() {
            guard let textField else { return }

            let selectedRange = textField.currentEditor()?.selectedRange
            shouldRestoreFocus = true
            focusGeneration += 1
            let generation = focusGeneration
            let delays: [TimeInterval] = [0, 0.02, 0.08]
            for (index, delay) in delays.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak textField] in
                    guard let self,
                          self.shouldRestoreFocus,
                          self.focusGeneration == generation,
                          let textField,
                          let window = textField.window else {
                        return
                    }

                    if self.shouldLeaveCurrentTextEditorFocused(textField, in: window) {
                        self.shouldRestoreFocus = false
                        return
                    }

                    if window.firstResponder !== textField.currentEditor() {
                        window.makeFirstResponder(textField)
                    }
                    if let editor = textField.currentEditor() {
                        let fallbackRange = NSRange(
                            location: (editor.string as NSString).length,
                            length: 0
                        )
                        editor.selectedRange = HomeMacToolbarSearchTextField.clampedSelectionRange(
                            selectedRange ?? fallbackRange,
                            in: editor.string
                        )
                    }

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

        private func dismissSearchFocus() {
            guard let textField else {
                parent.isFocused = false
                return
            }

            syncSearchText(from: textField)
            shouldRestoreFocus = false
            focusGeneration += 1
            let currentEditor = textField.currentEditor()
            if let window = textField.window,
               window.firstResponder === currentEditor || window.firstResponder === textField {
                window.makeFirstResponder(nil)
            }
            parent.isFocused = false
        }

        @discardableResult
        private func focusTextField(selectingText: Bool) -> Bool {
            guard let textField,
                  let window = textField.window else { return false }

            window.makeFirstResponder(textField)
            parent.isFocused = true
            let length = (textField.stringValue as NSString).length
            textField.currentEditor()?.selectedRange = NSRange(
                location: selectingText ? 0 : length,
                length: selectingText ? length : 0
            )
            return true
        }

        private func shouldLeaveCurrentTextEditorFocused(
            _ textField: NSTextField,
            in window: NSWindow
        ) -> Bool {
            guard let activeEditor = window.firstResponder as? NSTextView else {
                return false
            }

            return activeEditor !== textField.currentEditor()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HomeMacToolbarSearchTextEditorView {
        let textField = HomeMacToolbarSearchClickableTextField(string: text)
        textField.onMouseDown = { [weak coordinator = context.coordinator] in
            coordinator?.pointerFocusRequested()
        }
        textField.delegate = context.coordinator
        configure(textField)
        context.coordinator.textField = textField
        context.coordinator.installFocusObserver()
        return HomeMacToolbarSearchTextEditorView(textField: textField)
    }

    func updateNSView(_ nsView: HomeMacToolbarSearchTextEditorView, context: Context) {
        let textField = nsView.textField
        context.coordinator.parent = self
        context.coordinator.textField = textField
        (textField as? HomeMacToolbarSearchClickableTextField)?.onMouseDown = { [weak coordinator = context.coordinator] in
            coordinator?.pointerFocusRequested()
        }
        context.coordinator.dismissFocusIfNeeded(for: focusDismissRequestID)
        context.coordinator.focusIfNeeded(for: focusRequestID)
        configure(textField)

        if textField.stringValue != text {
            let selectedRange = textField.currentEditor()?.selectedRange
            textField.stringValue = text
            if let editor = textField.currentEditor() {
                editor.string = text
                if let selectedRange {
                    editor.selectedRange = Self.clampedSelectionRange(selectedRange, in: text)
                }
            }
        }
    }

    private static func clampedSelectionRange(_ range: NSRange, in text: String) -> NSRange {
        let textLength = (text as NSString).length
        let location = min(max(range.location, 0), textLength)
        let length = min(max(range.length, 0), textLength - location)
        return NSRange(location: location, length: length)
    }

    private func configure(_ textField: NSTextField) {
        textField.toolTip = HomeMacToolbarSearchCopy.help
        textField.controlSize = .large
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.alignment = .left
        textField.isEditable = true
        textField.isSelectable = true
        textField.font = NSFont.systemFont(
            ofSize: NSFont.systemFontSize(for: .large),
            weight: .semibold
        )
        textField.cell?.alignment = .left
        textField.cell?.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.cell?.lineBreakMode = .byTruncatingTail
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

private final class HomeMacToolbarSearchClickableTextField: NSTextField {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }
}

private final class HomeMacToolbarSearchTextEditorView: NSView {
    let textField: NSTextField

    init(textField: NSTextField) {
        self.textField = textField
        super.init(frame: .zero)

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("HomeMacToolbarSearchTextEditorView does not support decoding")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: HomeMacToolbarSearchLayout.height
        )
    }

    override func layout() {
        super.layout()
        textField.needsLayout = true
        textField.layoutSubtreeIfNeeded()
    }
}

struct HomeMacActivePlanFocusToolbarButton: View {
    let session: FocusSession
    let onPause: (FocusSession) -> Void
    let onResume: (FocusSession) -> Void
    let onFinish: (FocusSession) -> Void
    let onAbandon: (FocusSession) -> Void
    var trailingPadding: CGFloat = 8

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
        .padding(.trailing, trailingPadding)
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

struct HomeMacPlanFocusToolbarButton: View {
    let focusStartTaskCount: Int
    let isDisabled: Bool
    let onTaskFocusDurationSelected: (TimeInterval) -> Void
    var trailingPadding: CGFloat = 8

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
        .padding(.trailing, trailingPadding)
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
