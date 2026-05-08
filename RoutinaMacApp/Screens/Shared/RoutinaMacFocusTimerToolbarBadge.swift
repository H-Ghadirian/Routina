import SwiftData
import SwiftUI

private struct RoutinaMacFocusTimerStatusStoreKey: EnvironmentKey {
    static let defaultValue: RoutinaMacFocusTimerStatusStore? = nil
}

extension EnvironmentValues {
    var routinaMacFocusTimerStatusStore: RoutinaMacFocusTimerStatusStore? {
        get { self[RoutinaMacFocusTimerStatusStoreKey.self] }
        set { self[RoutinaMacFocusTimerStatusStoreKey.self] = newValue }
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

    let showsTitle: Bool
    let maxTitleWidth: CGFloat

    var body: some View {
        Group {
            let status = statusStore.status

            if status.isActive {
                Button {
                    open(status)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: status.kind?.systemImage ?? "timer")
                            .font(.caption.weight(.semibold))

                        Text(status.toolbarBadgeTitle)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)

                        if showsTitle {
                            Text(status.shortTitle)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: maxTitleWidth, alignment: .leading)
                        }
                    }
                    .foregroundStyle(status.tint)
                    .padding(.horizontal, 2)
                    .frame(height: 24)
                    .contentShape(Rectangle())
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
        guard let deepLink = status.deepLink else {
            RoutinaMacWindowRouter.shared.openHomeAndActivate()
            return
        }

        RoutinaMacWindowRouter.shared.openHomeAndActivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            RoutinaDeepLinkDispatcher.open(deepLink)
        }
    }
}

private extension RoutinaMacFocusTimerStatus {
    var toolbarBadgeTitle: String {
        switch kind {
        case .sprint:
            return "Sprint"
        case .task:
            return "Focus"
        case nil:
            return "Focus"
        }
    }

    var tint: Color {
        switch kind {
        case .sprint:
            return .blue
        case .task:
            return .teal
        case nil:
            return .secondary
        }
    }

    var toolbarHelpTitle: String {
        let target = kind == .sprint ? "sprint" : "task"
        return "Open active \(target): \(shortTitle)"
    }
}
