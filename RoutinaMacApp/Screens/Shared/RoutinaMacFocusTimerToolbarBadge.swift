import AppKit
import SwiftData
import SwiftUI

private struct RoutinaMacFocusTimerStatusStoreKey: EnvironmentKey {
    static let defaultValue: RoutinaMacFocusTimerStatusStore? = nil
}

private struct RoutinaMacOpenFocusTimerTargetKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ((RoutinaDeepLink?) -> Void)? = nil
}

extension EnvironmentValues {
    var routinaMacFocusTimerStatusStore: RoutinaMacFocusTimerStatusStore? {
        get { self[RoutinaMacFocusTimerStatusStoreKey.self] }
        set { self[RoutinaMacFocusTimerStatusStoreKey.self] = newValue }
    }

    var routinaMacOpenFocusTimerTarget: ((RoutinaDeepLink?) -> Void)? {
        get { self[RoutinaMacOpenFocusTimerTargetKey.self] }
        set { self[RoutinaMacOpenFocusTimerTargetKey.self] = newValue }
    }
}

struct RoutinaMacFocusTimerToolbarBadge: View {
    @Environment(\.routinaMacFocusTimerStatusStore) private var statusStore

    var showsTitle = true
    var maxTitleWidth: CGFloat = 170
    var hiddenKinds: [RoutinaMacFocusTimerStatus.Kind] = []

    var body: some View {
        if let statusStore {
            RoutinaMacFocusTimerToolbarBadgeContent(
                statusStore: statusStore,
                showsTitle: showsTitle,
                maxTitleWidth: maxTitleWidth,
                hiddenKinds: hiddenKinds
            )
        }
    }
}

struct RoutinaMacFocusTimerToolbarItem: ToolbarContent {
    var showsTitle = true
    var maxTitleWidth: CGFloat = 170
    var hiddenKinds: [RoutinaMacFocusTimerStatus.Kind] = []

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            RoutinaMacFocusTimerToolbarBadge(
                showsTitle: showsTitle,
                maxTitleWidth: maxTitleWidth,
                hiddenKinds: hiddenKinds
            )
        }
    }
}

private struct RoutinaMacFocusTimerToolbarBadgeContent: View {
    @ObservedObject var statusStore: RoutinaMacFocusTimerStatusStore
    @Environment(\.calendar) private var calendar
    @Environment(\.modelContext) private var modelContext
    @Environment(\.routinaMacOpenFocusTimerTarget) private var openFocusTimerTarget

    let showsTitle: Bool
    let maxTitleWidth: CGFloat
    let hiddenKinds: [RoutinaMacFocusTimerStatus.Kind]

    var body: some View {
        Group {
            let status = statusStore.status

            if shouldShow(status) {
                Menu {
                    if status.deepLink != nil {
                        Button {
                            open(status)
                        } label: {
                            Label("Open \(status.targetDisplayTitle)", systemImage: "arrow.up.forward.app")
                        }

                        Divider()
                    }

                    if status.supportsPauseResume {
                        Button {
                            togglePause(status)
                        } label: {
                            Label(status.isPaused ? "Resume" : "Pause", systemImage: status.isPaused ? "play.fill" : "pause.fill")
                        }
                    }

                    Button {
                        finish(status)
                    } label: {
                        Label("Finish", systemImage: "checkmark.circle.fill")
                    }

                    if status.supportsAbandon {
                        Divider()

                        Button(role: .destructive) {
                            abandon(status)
                        } label: {
                            Label("Abandon", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    RoutinaMacFocusTimerToolbarLabel(
                        status: status,
                        title: showsTitle ? status.toolbarTitle(fitting: maxTitleWidth) : nil
                    )
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .controlSize(.small)
                .help(status.toolbarHelpTitle)
            }
        }
        .onAppear {
            statusStore.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            statusStore.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .routineDidUpdate)) { _ in
            statusStore.refresh()
        }
    }

    private func shouldShow(_ status: RoutinaMacFocusTimerStatus) -> Bool {
        guard status.isActive else { return false }
        guard let kind = status.kind else { return true }
        return !hiddenKinds.contains(kind)
    }

    private func open(_ status: RoutinaMacFocusTimerStatus) {
        if let openFocusTimerTarget {
            openFocusTimerTarget(status.deepLink)
            return
        }

        guard let deepLink = status.deepLink else {
            RoutinaMacWindowRouter.shared.openHomeAndActivate()
            return
        }

        RoutinaMacWindowRouter.shared.openHomeAndActivate()
        RoutinaDeepLinkDispatcher.open(deepLink)
    }

    private func togglePause(_ status: RoutinaMacFocusTimerStatus) {
        guard let sessionID = status.id else { return }

        do {
            if status.isPaused {
                _ = try FocusSessionSupport.resumeFocus(
                    sessionID: sessionID,
                    kind: status.focusSessionKind,
                    context: modelContext
                )
            } else {
                _ = try FocusSessionSupport.pauseFocus(
                    sessionID: sessionID,
                    kind: status.focusSessionKind,
                    context: modelContext
                )
            }
            statusStore.refresh()
        } catch {
            NSLog("Failed to toggle focus timer pause state from toolbar: \(error.localizedDescription)")
        }
    }

    private func finish(_ status: RoutinaMacFocusTimerStatus) {
        guard let sessionID = status.id else { return }

        do {
            _ = try FocusSessionSupport.finishFocus(
                sessionID: sessionID,
                kind: status.focusSessionKind,
                context: modelContext,
                calendar: calendar
            )
            statusStore.refresh()
        } catch {
            NSLog("Failed to finish focus timer from toolbar: \(error.localizedDescription)")
        }
    }

    private func abandon(_ status: RoutinaMacFocusTimerStatus) {
        guard let sessionID = status.id else { return }

        do {
            _ = try FocusSessionSupport.abandonFocus(
                sessionID: sessionID,
                kind: status.focusSessionKind,
                context: modelContext
            )
            statusStore.refresh()
        } catch {
            NSLog("Failed to abandon focus timer from toolbar: \(error.localizedDescription)")
        }
    }
}

private struct RoutinaMacFocusTimerToolbarLabel: View {
    let status: RoutinaMacFocusTimerStatus
    let title: String?

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.systemImage)
                .font(.caption.weight(.semibold))

            RoutinaMacFocusTimerToolbarTimeText(status: status)

            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(height: 28)
        .routinaGlassPill(tint: status.tint, tintOpacity: 0.12, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(status.tint.opacity(0.22), lineWidth: 0.75)
        )
        .contentShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
    }
}

private struct RoutinaMacFocusTimerToolbarTimeText: View {
    let status: RoutinaMacFocusTimerStatus

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            let timeText = status.menuBarTimeText(at: context.date)

            ZStack(alignment: .leading) {
                Text("+00:00:00")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .hidden()

                Text(timeText)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }
}

private extension RoutinaMacFocusTimerStatus {
    var focusSessionKind: FocusSessionKind? {
        switch kind {
        case .task:
            return .task
        case .tag:
            return .tag
        case .sprint:
            return .sprint
        case .unassigned:
            return .unassigned
        case nil:
            return nil
        }
    }

    var supportsPauseResume: Bool {
        switch kind {
        case .task, .tag, .unassigned:
            return true
        case .sprint, nil:
            return false
        }
    }

    var supportsAbandon: Bool {
        switch kind {
        case .task, .tag, .unassigned:
            return true
        case .sprint, nil:
            return false
        }
    }

    var targetDisplayTitle: String {
        switch kind {
        case .task:
            return "Task"
        case .tag:
            return "Tag"
        case .sprint:
            return "Board"
        case .unassigned:
            return "Focus"
        case nil:
            return "Timer"
        }
    }

    var tint: Color {
        switch kind {
        case .sprint:
            return .blue
        case .task, .tag:
            return .teal
        case .unassigned:
            return .orange
        case nil:
            return .secondary
        }
    }

    var toolbarHelpTitle: String {
        let target: String
        switch kind {
        case .sprint:
            target = "sprint"
        case .task:
            target = "task"
        case .tag:
            target = "tag"
        case .unassigned:
            target = "focus"
        case nil:
            target = "timer"
        }
        if supportsPauseResume || supportsAbandon {
            return "Manage active \(target): \(title)"
        }
        return "Open active \(target): \(title)"
    }

    func toolbarTitle(fitting maxWidth: CGFloat) -> String? {
        guard maxWidth > 0 else { return nil }

        let font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        let width = (title as NSString).size(withAttributes: [.font: font]).width
        return width <= maxWidth ? title : nil
    }
}
