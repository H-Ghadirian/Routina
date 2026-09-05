import SwiftUI
#if canImport(ActivityKit)
    import ActivityKit
#endif
import SwiftData

enum IOSSearchPresentationPolicy {
    static let inputDebounce: Duration = .milliseconds(120)
}

enum AppTabBarItem: Hashable {
    case home
    case search
    case goals
    case addTask
    case stats
    case settings

    init(tab: Tab) {
        switch tab {
        case .home:
            self = .home
        case .search:
            self = .search
        case .goals:
            self = .goals
        case .timeline:
            self = .home
        case .stats:
            self = .stats
        case .settings:
            self = .settings
        case .more:
            self = .settings
        }
    }

    var appTab: Tab? {
        switch self {
        case .home:
            return .home
        case .search:
            return .search
        case .goals:
            return .goals
        case .addTask:
            return nil
        case .stats:
            return .stats
        case .settings:
            return .settings
        }
    }
}

struct SprintFocusDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
}

enum NewTabAction: CaseIterable, Equatable, Hashable, Identifiable {
    case createTask
    case focus

    static let orderedActions: [NewTabAction] = [.createTask, .focus]

    var id: Self { self }

    var title: String {
        switch self {
        case .createTask:
            return "Create Task"
        case .focus:
            return "Focus"
        }
    }

    var systemImage: String {
        switch self {
        case .createTask:
            return "checklist"
        case .focus:
            return "timer"
        }
    }
}

extension AppColorScheme {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct NewActionListSheet: View {
    let actions: [NewTabAction]
    let onSelect: (NewTabAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(actions.enumerated()), id: \.element) { index, action in
                        actionButton(action)

                        if index < actions.count - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("New")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func actionButton(_ action: NewTabAction) -> some View {
        Button {
            onSelect(action)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: action.systemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)

                Text(action.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.title)
    }
}

enum IOSActiveFocusDeepLinkResolver {
    @MainActor
    static func deepLink(
        modelContext: ModelContext,
        includeRecordedFallback: Bool = true
    ) throws -> RoutinaDeepLink? {
        if let activityFocus = activeLiveActivityDeepLink() {
            return activityFocus.deepLink
        }

        let taskFocus = try activeTaskFocusDeepLink(modelContext: modelContext)
        let sprintFocus = try activeSprintFocusDeepLink(modelContext: modelContext)

        switch (taskFocus, sprintFocus) {
        case let (.some(task), .some(sprint)):
            return task.startedAt >= sprint.startedAt ? task.deepLink : sprint.deepLink
        case let (.some(task), nil):
            return task.deepLink
        case let (nil, .some(sprint)):
            return sprint.deepLink
        case (nil, nil):
            guard includeRecordedFallback else { return nil }
            return RoutinaActiveFocusOpenDispatcher.recordedActiveFocusDeepLink()
        }
    }

    @MainActor
    private static func activeLiveActivityDeepLink() -> ActiveFocusDeepLink? {
        #if canImport(ActivityKit)
            let deepLinks: [ActiveFocusDeepLink] = Activity<FocusTimerActivityAttributes>.activities
                .compactMap { (activity: Activity<FocusTimerActivityAttributes>) -> ActiveFocusDeepLink? in
                    let kind = activity.attributes.focusKind ?? .task
                    guard let targetID = activity.attributes.targetID ?? activity.attributes.taskID else {
                        return nil
                    }

                    let deepLink: RoutinaDeepLink
                    switch kind {
                    case .task:
                        deepLink = .task(targetID)
                    case .sprint:
                        deepLink = .sprint(targetID)
                    case .unassigned:
                        return nil
                    }

                    return ActiveFocusDeepLink(
                        deepLink: deepLink,
                        startedAt: activity.content.state.startedAt
                    )
                }
            return deepLinks.max { $0.startedAt < $1.startedAt }
        #else
            return nil
        #endif
    }

    @MainActor
    private static func activeTaskFocusDeepLink(
        modelContext: ModelContext
    ) throws -> ActiveFocusDeepLink? {
        let sessions = try modelContext.fetch(FetchDescriptor<FocusSession>())
        guard
            let session =
                sessions
                .filter({ $0.state == .active })
                .max(by: { ($0.startedAt ?? .distantPast) < ($1.startedAt ?? .distantPast) })
        else {
            return nil
        }
        guard session.isTaskFocus else {
            return nil
        }

        return ActiveFocusDeepLink(
            deepLink: .task(session.taskID),
            startedAt: session.startedAt ?? .distantPast
        )
    }

    @MainActor
    private static func activeSprintFocusDeepLink(
        modelContext: ModelContext
    ) throws -> ActiveFocusDeepLink? {
        let sessions = try modelContext.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        guard
            let session =
                sessions
                .filter({ $0.stoppedAt == nil })
                .max(by: { $0.startedAt < $1.startedAt })
        else {
            return nil
        }

        return ActiveFocusDeepLink(
            deepLink: .sprint(session.sprintID),
            startedAt: session.startedAt
        )
    }
}

private struct ActiveFocusDeepLink {
    let deepLink: RoutinaDeepLink
    let startedAt: Date
}
