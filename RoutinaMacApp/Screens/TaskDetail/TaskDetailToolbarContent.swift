import AppKit
import SwiftUI
import ComposableArchitecture

struct TaskDetailToolbarContent: ToolbarContent {
    let store: StoreOf<TaskDetailFeature>
    let showsPrincipalToolbarTitle: Bool
    let isInlineEditPresented: Bool

    var body: some ToolbarContent {
        if showsPrincipalToolbarTitle {
            RoutinaMacFocusTimerToolbarItem()

            ToolbarItem(placement: .principal) {
                if isInlineEditPresented {
                    editTitle
                } else {
                    Text(store.routineEmoji)
                        .font(TaskDetailPlatformStyle.principalTitleFont)
                }
            }
        }
    }

    private var editTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
            Text("Edit Task")
                .lineLimit(1)
        }
        .font(TaskDetailPlatformStyle.principalTitleFont)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.10, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

struct TaskDetailActionClusterView: View {
    enum Style {
        case fullDetail
        case companionPane
    }

    private enum Metrics {
        static let controlHeight: CGFloat = 34
        static let iconControlWidth: CGFloat = 42
        static let clusterHorizontalPadding: CGFloat = 12
        static let textCornerRadius: CGFloat = 10
        static let iconCornerRadius: CGFloat = 8
    }

    let store: StoreOf<TaskDetailFeature>
    let style: Style
    let showsEditButton: Bool
    let onExpandCompanion: (() -> Void)?
    let onMinimizeFullscreen: (() -> Void)?
    let onClose: (() -> Void)?
    let isTaskSharingEnabled: Bool

    @State private var isPauseUntilPresented = false
    @State private var isTaskLifecycleActionsMenuPresented = false
    @State private var taskLifecycleActionsMenuRequestID = 0

    var body: some View {
        HStack(spacing: 8) {
            actionButtons
            if showsFullDetailActions {
                linkToolbarMenu
            }
            if showsFullDetailActions && isTaskSharingEnabled {
                CloudSharingToolbarButton(task: store.task)
            }
            if showsFullDetailActions && showsEditButton {
                toolbarIconButton(
                    title: "Edit",
                    systemImage: "square.and.pencil"
                ) {
                    store.send(.setEditSheet(true))
                }
            }
            if let onExpandCompanion {
                toolbarIconButton(
                    title: "Open Fullscreen",
                    systemImage: "arrow.up.left.and.arrow.down.right",
                    action: onExpandCompanion
                )
            }
            if let onMinimizeFullscreen {
                toolbarIconButton(
                    title: "Return to task details sidebar",
                    systemImage: "arrow.down.right.and.arrow.up.left",
                    action: onMinimizeFullscreen
                )
            }
            if let onClose {
                toolbarIconButton(
                    title: closeButtonTitle,
                    systemImage: "xmark",
                    action: onClose
                )
            }
        }
        .padding(.horizontal, Metrics.clusterHorizontalPadding)
        .padding(.vertical, 4)
        .routinaGlassPill(tint: .secondary, tintOpacity: 0.05, interactive: true)
        .contentShape(Capsule(style: .continuous))
        .sheet(isPresented: $isPauseUntilPresented) {
            TaskDetailPauseUntilSheet(
                actionTitle: pauseUntilActionTitle
            ) { pauseUntil in
                store.send(.pauseUntilTapped(pauseUntil))
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            store.send(store.completionButtonAction)
        } label: {
            completionActionLabel
        }
        .buttonStyle(.plain)
        .disabled(store.isCompletionButtonDisabled)
        .help(store.completionButtonTitle)
        .accessibilityLabel(store.completionButtonTitle)

        if showsFullDetailActions {
            taskLifecycleActionsMenu
        }
    }

    private var taskLifecycleActionsMenu: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                isTaskLifecycleActionsMenuPresented = true
            }
            taskLifecycleActionsMenuRequestID &+= 1
        } label: {
            taskLifecycleActionsMenuLabel
        }
        .buttonStyle(.plain)
        .background {
            TaskDetailOverflowMenuPresenter(
                requestID: taskLifecycleActionsMenuRequestID,
                isPresented: $isTaskLifecycleActionsMenuPresented,
                elements: taskLifecycleActionsMenuElements
            )
        }
        .fixedSize()
        .help("More task actions")
        .accessibilityLabel("More task actions")
    }

    private var taskLifecycleActionsMenuElements: [TaskDetailOverflowMenuElement] {
        var elements: [TaskDetailOverflowMenuElement] = []

        if showsPauseResumeButton {
            if store.task.isArchived() {
                elements.append(
                    .action(
                        TaskDetailOverflowMenuAction(
                            title: pauseActionTitle,
                            systemImage: pauseSystemImage,
                            action: { store.send(.resumeTapped) }
                        )
                    )
                )
            } else {
                elements.append(
                    .action(
                        TaskDetailOverflowMenuAction(
                            title: pauseActionTitle,
                            systemImage: pauseSystemImage,
                            action: { store.send(.pauseTapped) }
                        )
                    )
                )
                elements.append(
                    .action(
                        TaskDetailOverflowMenuAction(
                            title: pauseUntilActionTitle,
                            systemImage: "clock.arrow.circlepath",
                            action: { isPauseUntilPresented = true }
                        )
                    )
                )
            }
        }

        if showsCancelTodoButton {
            elements.append(
                .action(
                    TaskDetailOverflowMenuAction(
                        title: store.cancelTodoButtonTitle,
                        systemImage: "slash.circle",
                        isEnabled: !store.isCancelTodoButtonDisabled,
                        action: { store.send(.cancelTodo) }
                    )
                )
            )
        }

        elements.append(.separator)
        elements.append(
            .action(
                TaskDetailOverflowMenuAction(
                    title: "Delete",
                    systemImage: "trash",
                    role: .destructive,
                    action: { store.send(.setDeleteConfirmation(true)) }
                )
            )
        )

        return elements
    }

    private var taskLifecycleActionsMenuLabel: some View {
        Image(systemName: "ellipsis.vertical")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(isTaskLifecycleActionsMenuPresented ? Color.primary : Color.secondary)
            .frame(width: Metrics.controlHeight, height: Metrics.controlHeight)
            .background(
                Circle()
                    .fill(
                        isTaskLifecycleActionsMenuPresented
                            ? Color.accentColor.opacity(0.20)
                            : Color.clear
                    )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.accentColor.opacity(
                            isTaskLifecycleActionsMenuPresented ? 0.28 : 0
                        ),
                        lineWidth: 1
                    )
            )
            .frame(width: Metrics.iconControlWidth, height: Metrics.controlHeight)
            .contentShape(Rectangle())
    }

    private var showsFullDetailActions: Bool {
        style == .fullDetail
    }

    private var pauseUntilActionTitle: String {
        store.task.isOneOffTask ? "Archive Until…" : "Pause Until…"
    }

    private var closeButtonTitle: String {
        switch style {
        case .fullDetail:
            return "Close details and show Planner"
        case .companionPane:
            return "Close details"
        }
    }

    private func toolbarIconButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            toolbarIconLabel(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .help(title)
    }

    private var linkToolbarMenu: some View {
        toolbarIconChrome {
            RoutinaDeepLinkShareMenu(
                title: RoutineTask.trimmedName(store.task.name) ?? "Untitled task",
                deepLink: .task(store.task.id),
                presentation: .plainToolbar
            )
        }
    }

    private var completionActionLabel: some View {
        HStack(spacing: 6) {
            if let systemImage = store.completionButtonSystemImage {
                Image(systemName: systemImage)
            }
            Text(store.completionButtonTitle)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 16)
        .frame(minWidth: 68, minHeight: Metrics.controlHeight)
        .background(
            RoundedRectangle(cornerRadius: Metrics.textCornerRadius, style: .continuous)
                .fill(completionTint)
        )
        .contentShape(RoundedRectangle(cornerRadius: Metrics.textCornerRadius, style: .continuous))
        .opacity(store.isCompletionButtonDisabled ? 0.55 : 1)
    }

    private func toolbarIconLabel(systemImage: String) -> some View {
        toolbarIconChrome {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func toolbarIconChrome<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: Metrics.iconControlWidth, height: Metrics.controlHeight)
            .background(
                RoundedRectangle(cornerRadius: Metrics.iconCornerRadius, style: .continuous)
                    .fill(Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.iconCornerRadius, style: .continuous)
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Metrics.iconCornerRadius, style: .continuous))
    }

    private var showsCancelTodoButton: Bool {
        store.task.isOneOffTask && !store.task.isCompletedOneOff && !store.task.isCanceledOneOff
    }

    private var showsPauseResumeButton: Bool {
        !store.task.isOneOffTask || showsCancelTodoButton
    }

    private var completionTint: Color {
        if store.task.isMultiDayRoutine && store.task.isOngoing {
            return Color.orange
        }
        return store.canUndoSelectedDate ? Color.orange : Color.green
    }

    private var pauseActionTitle: String {
        if store.task.isOneOffTask {
            return store.task.isArchived() ? "Restore" : "Archive"
        }
        return store.task.isArchived() ? "Resume" : "Pause"
    }

    private var pauseSystemImage: String {
        if store.task.isOneOffTask {
            return store.task.isArchived() ? "arrow.uturn.backward" : "archivebox"
        }
        return store.task.isArchived() ? "play.fill" : "pause.fill"
    }

}

private enum TaskDetailOverflowMenuElement {
    case action(TaskDetailOverflowMenuAction)
    case separator
}

private struct TaskDetailOverflowMenuAction {
    enum Role: Equatable {
        case standard
        case destructive
    }

    let title: String
    let systemImage: String
    var isEnabled = true
    var role: Role = .standard
    let action: () -> Void
}

@MainActor
private struct TaskDetailOverflowMenuPresenter: NSViewRepresentable {
    let requestID: Int
    @Binding var isPresented: Bool
    let elements: [TaskDetailOverflowMenuElement]

    func makeNSView(context: Context) -> TaskDetailOverflowMenuAnchorView {
        TaskDetailOverflowMenuAnchorView()
    }

    func updateNSView(_ nsView: TaskDetailOverflowMenuAnchorView, context: Context) {
        let coordinator = context.coordinator
        coordinator.elements = elements
        let presentationBinding = $isPresented
        coordinator.setPresented = { isPresented in
            guard presentationBinding.wrappedValue != isPresented else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                presentationBinding.wrappedValue = isPresented
            }
        }

        guard requestID != coordinator.lastRequestID else { return }
        coordinator.lastRequestID = requestID
        guard requestID > 0 else { return }

        DispatchQueue.main.async {
            coordinator.presentMenu(from: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var elements: [TaskDetailOverflowMenuElement] = []
        var lastRequestID = 0
        var setPresented: ((Bool) -> Void)?

        private var actionHandlers: [() -> Void] = []
        private var isMenuPresented = false

        func presentMenu(from anchorView: NSView) {
            guard !isMenuPresented else { return }
            guard anchorView.window != nil else {
                setPresented?(false)
                return
            }

            isMenuPresented = true
            setPresented?(true)

            let menu = makeMenu()
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: anchorView.bounds.midX, y: anchorView.bounds.minY),
                in: anchorView
            )

            isMenuPresented = false
            setPresented?(false)
        }

        private func makeMenu() -> NSMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false
            actionHandlers = []

            for element in elements {
                switch element {
                case .separator:
                    menu.addItem(.separator())

                case let .action(action):
                    let item = NSMenuItem(
                        title: action.title,
                        action: #selector(performAction(_:)),
                        keyEquivalent: ""
                    )
                    item.target = self
                    item.tag = actionHandlers.count
                    item.isEnabled = action.isEnabled
                    item.image = NSImage(
                        systemSymbolName: action.systemImage,
                        accessibilityDescription: action.title
                    )
                    if action.role == .destructive {
                        item.attributedTitle = NSAttributedString(
                            string: action.title,
                            attributes: [.foregroundColor: NSColor.systemRed]
                        )
                    }
                    actionHandlers.append(action.action)
                    menu.addItem(item)
                }
            }

            return menu
        }

        @objc private func performAction(_ sender: NSMenuItem) {
            guard actionHandlers.indices.contains(sender.tag) else { return }
            actionHandlers[sender.tag]()
        }
    }
}

private final class TaskDetailOverflowMenuAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
