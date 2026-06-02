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

    var body: some View {
        if let statusStore {
            RoutinaMacFocusTimerToolbarBadgeContent(
                statusStore: statusStore,
                showsTitle: showsTitle,
                maxTitleWidth: maxTitleWidth
            )
        }
    }
}

struct RoutinaMacFocusTimerToolbarItem: ToolbarContent {
    var showsTitle = true
    var maxTitleWidth: CGFloat = 170

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            RoutinaMacFocusTimerToolbarBadge(
                showsTitle: showsTitle,
                maxTitleWidth: maxTitleWidth
            )
        }
    }
}

private struct RoutinaMacFocusTimerToolbarBadgeContent: View {
    @ObservedObject var statusStore: RoutinaMacFocusTimerStatusStore
    @Environment(\.routinaMacOpenFocusTimerTarget) private var openFocusTimerTarget

    let showsTitle: Bool
    let maxTitleWidth: CGFloat

    var body: some View {
        Group {
            let status = statusStore.status

            if status.isActive {
                Button {
                    open(status)
                } label: {
                    RoutinaMacFocusTimerToolbarLabel(
                        status: status,
                        title: showsTitle ? status.toolbarTitle(fitting: maxTitleWidth) : nil
                    )
                }
                .buttonStyle(.plain)
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

            Text(timeText)
            .font(.caption.monospacedDigit().weight(.semibold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .transaction { transaction in
                transaction.animation = nil
            }
        }
    }
}

private extension RoutinaMacFocusTimerStatus {
    var tint: Color {
        switch kind {
        case .sprint:
            return .blue
        case .task:
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
        case .unassigned:
            target = "focus"
        case nil:
            target = "timer"
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
