import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif
import ComposableArchitecture
import SwiftData
import WidgetKit

struct AppView: View {
    let store: StoreOf<AppFeature>
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var searchText = ""
    @State private var appliedSearchText = ""
    @State private var searchPresentationUpdateTask: Task<Void, Never>?
    @State private var presentedSprintFocusDeepLink: SprintFocusDeepLinkPresentation?
    @State private var isNewActionListPresented = false
    @State private var pendingNewTabAction: NewTabAction?
    @State private var focusStartPresentation: IOSFocusStartPresentation?
    @State private var shouldCreateTaskAfterFocusDismissal = false
    @State private var activeFocusControlPresentation: ActiveFocusControlPresentation?
    @State private var newFocusErrorMessage: String?
    @State private var timelinePresentationID = UUID()
    @AppStorage(UserDefaultStringValueKey.appSettingAppColorScheme.rawValue, store: SharedDefaults.app)
    private var appColorSchemeRawValue = AppColorScheme.system.rawValue
    @AppStorage(UserDefaultBoolValueKey.appSettingGoalsTabEnabled.rawValue, store: SharedDefaults.app)
    private var isGoalsTabEnabled = false

    var body: some View {
let tabView = TabView(
    selection: selectedTabBinding
) {
    SwiftUI.Tab(Tab.home.rawValue, systemImage: "house", value: AppTabBarItem.home) {
        platformHomeView
    }

    SwiftUI.Tab(Tab.search.rawValue, systemImage: "magnifyingglass", value: AppTabBarItem.search, role: .search) {
        platformSearchHomeView(searchText: $appliedSearchText)
            .searchable(text: $searchText, prompt: "Search repeating and one-time tasks")
            .onChange(of: searchText) { _, rawSearchText in
                scheduleSearchPresentationUpdate(for: rawSearchText)
            }
    }

    if !usesCompactLayout && isGoalsTabEnabled {
        SwiftUI.Tab(Tab.goals.rawValue, systemImage: "target", value: AppTabBarItem.goals) {
            GoalsTCAView(
                store: store.scope(state: \.goals, action: \.goals)
            )
        }
    }

    SwiftUI.Tab("New", systemImage: "plus", value: AppTabBarItem.addTask) {
        Color.clear
    }

    SwiftUI.Tab(Tab.stats.rawValue, systemImage: "chart.bar.xaxis", value: AppTabBarItem.stats) {
        StatsViewWrapper(
            store: store.scope(state: \.stats, action: \.stats)
        )
    }

    SwiftUI.Tab(Tab.settings.rawValue, systemImage: "gear", value: AppTabBarItem.settings) {
        SettingsTCAView(
            store: store.scope(state: \.settings, action: \.settings)
        )
    }
}
Group {
    AppLockGate {
        tabView
            .tabViewSearchActivation(.searchTabSelection)
            .onReceive(NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)) { _ in
                PlatformSupport.applyAppIcon(.persistedSelection)
                store.send(.cloudSettingsChanged)
            }
            .task {
                store.send(.onAppear)
                normalizeRetiredTabSelectionIfNeeded()
                handlePendingDeepLink()
            }
    }
}
.preferredColorScheme(appColorScheme.preferredColorScheme)
.onOpenURL(perform: handleOpenURL)
.onReceive(NotificationCenter.default.publisher(for: .routinaOpenDeepLink)) { notification in
    handleDeepLinkNotification(notification)
}
.onReceive(NotificationCenter.default.publisher(for: .routinaOpenActiveFocus)) { _ in
    handleActiveFocusOpenRequest()
}
.onContinueUserActivity(NSUserActivityTypeLiveActivity) { userActivity in
    handleLiveActivityContinuation(userActivity)
}
.sheet(item: $presentedSprintFocusDeepLink) { presentation in
    SprintFocusDeepLinkView(sprintID: presentation.id)
}
.sheet(isPresented: $isNewActionListPresented, onDismiss: performPendingNewTabAction) {
    NewActionListSheet(
        actions: NewTabAction.orderedActions,
        onSelect: queueNewTabAction
    )
    .presentationDetents([.height(200)])
    .presentationDragIndicator(.visible)
}
.sheet(item: $focusStartPresentation, onDismiss: performPendingFocusTaskCreation) { presentation in
    IOSFocusStartSheet(
        presentation: presentation,
        onCreateTask: queueFocusTaskCreation
    )
}
.sheet(item: $activeFocusControlPresentation) { presentation in
    ActiveFocusControlSheet(
        presentation: presentation,
        onOpenTask: openFocusTask
    )
}
.sheet(isPresented: timelineRouteBinding) {
    TimelineView(
        store: store.scope(state: \.timeline, action: \.timeline),
        presentationID: timelinePresentationID,
        isActive: store.selectedTab == .timeline
    )
}
.sheet(isPresented: compactGoalsRouteBinding) {
    GoalsTCAView(
        store: store.scope(state: \.goals, action: \.goals)
    )
}
.alert("Couldn’t Open Focus", isPresented: newFocusErrorBinding) {
    Button("OK", role: .cancel) {
        newFocusErrorMessage = nil
    }
} message: {
    Text(newFocusErrorMessage ?? "Focus is temporarily unavailable.")
}
.awayModeGate()
.sleepModeGate()
    }

    private var appColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRawValue) ?? .system
    }

    private func scheduleSearchPresentationUpdate(for rawSearchText: String) {
        searchPresentationUpdateTask?.cancel()

        guard !rawSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            RoutinaPerformanceProfiler.shared.recordInteraction(.searchQueryCleared)
            appliedSearchText = rawSearchText
            return
        }

        RoutinaPerformanceProfiler.shared.recordInteraction(.searchQueryEdited)

        searchPresentationUpdateTask = Task { @MainActor in
            do {
                try await Task.sleep(for: IOSSearchPresentationPolicy.inputDebounce)
            } catch {
                return
            }

            guard !Task.isCancelled, searchText == rawSearchText else { return }
            appliedSearchText = rawSearchText
            RoutinaPerformanceProfiler.shared.recordInteraction(.searchQueryApplied)
        }
    }

    private var selectedTabBinding: Binding<AppTabBarItem> {
        Binding(
            get: { selectedTabForCurrentLayout },
            set: { tab in
                selectTab(tab)
            }
        )
    }

    private var selectedTabForCurrentLayout: AppTabBarItem {
        if store.selectedTab == .timeline {
            return .home
        }

        if store.selectedTab == .more {
            return .settings
        }

        if store.selectedTab == .goals,
           usesCompactLayout || !isGoalsTabEnabled {
            return .home
        }

        return AppTabBarItem(tab: store.selectedTab)
    }

    private var usesCompactLayout: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    private func normalizeRetiredTabSelectionIfNeeded() {
        if store.selectedTab == .more {
            store.send(.tabSelected(.settings))
        }
    }

    @MainActor
    private func selectTab(_ tab: AppTabBarItem) {
        if tab == .addTask {
            openNewTabActionDestination()
            return
        }

        guard let appTab = tab.appTab else { return }
        if let interaction = RoutinaPerformanceInteraction.navigationTab(named: appTab.rawValue) {
            RoutinaPerformanceProfiler.shared.recordInteraction(interaction)
        }
        store.send(.tabSelected(appTab))
    }

    @MainActor
    private func openNewTabActionDestination() {
        RoutinaPerformanceProfiler.shared.recordInteraction(.newActionMenuOpened)
        isNewActionListPresented = true
    }

    private func queueNewTabAction(_ action: NewTabAction) {
        pendingNewTabAction = action
        isNewActionListPresented = false
    }

    @MainActor
    private func performPendingNewTabAction() {
        guard let action = pendingNewTabAction else { return }
        pendingNewTabAction = nil
        performNewTabAction(action)
    }

    @MainActor
    private func performNewTabAction(_ action: NewTabAction) {
        RoutinaPerformanceProfiler.shared.recordInteraction(
            performanceInteraction(for: action)
        )

        switch action {
        case .createTask:
            openNewTask()
        case .focus:
            openFocus()
        }
    }

    private func performanceInteraction(
        for action: NewTabAction
    ) -> RoutinaPerformanceInteraction {
        switch action {
        case .createTask: return .newTaskRequested
        case .focus: return .newFocusRequested
        }
    }

    private func openNewTask() {
        store.send(.tabSelected(.home))
        store.send(.home(.setSmartAddTaskSheet(true)))
    }

    @MainActor
    private func queueFocusTaskCreation() {
        shouldCreateTaskAfterFocusDismissal = true
        focusStartPresentation = nil
    }

    @MainActor
    private func performPendingFocusTaskCreation() {
        guard shouldCreateTaskAfterFocusDismissal else { return }
        shouldCreateTaskAfterFocusDismissal = false
        openNewTask()
    }

    @MainActor
    private func openFocus() {
        do {
            let focusSessions = try modelContext.fetch(FetchDescriptor<FocusSession>())
            if let activeSession = focusSessions
                .filter({ $0.state == .active })
                .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
                .first {
                activeFocusControlPresentation = ActiveFocusControlPresentation(
                    id: activeSession.id,
                    kind: activeSessionKind(activeSession)
                )
                return
            }

            let sprintFocusSessions = try modelContext.fetch(
                FetchDescriptor<SprintFocusSessionRecord>()
            )
            if let activeSprint = sprintFocusSessions
                .filter({ $0.stoppedAt == nil })
                .sorted(by: { $0.startedAt > $1.startedAt })
                .first {
                activeFocusControlPresentation = ActiveFocusControlPresentation(
                    id: activeSprint.id,
                    kind: .sprint
                )
                return
            }

            let referenceDate = Date()
            let tasks = try modelContext.fetch(FetchDescriptor<RoutineTask>())
                .filter { task in
                    !task.isArchived(referenceDate: referenceDate, calendar: .current)
                        && !task.isCompletedOneOff
                        && !task.isCanceledOneOff
                }
            focusStartPresentation = IOSFocusStartPresentation.make(
                tasks: tasks,
                focusSessions: focusSessions
            )
        } catch {
            newFocusErrorMessage = error.localizedDescription
        }
    }

    private func activeSessionKind(_ session: FocusSession) -> FocusSessionKind {
        if session.isTagFocus {
            return .tag
        }
        if session.isUnassigned {
            return .unassigned
        }
        return .task
    }

    private func openFocusTask(_ taskID: UUID) {
        store.send(.openDeepLink(.task(taskID)))
    }

    private var timelineRouteBinding: Binding<Bool> {
        Binding(
            get: { store.selectedTab == .timeline },
            set: { isPresented in
                if !isPresented, store.selectedTab == .timeline {
                    store.send(.tabSelected(.home))
                }
            }
        )
    }

    private var compactGoalsRouteBinding: Binding<Bool> {
        Binding(
            get: { usesCompactLayout && isGoalsTabEnabled && store.selectedTab == .goals },
            set: { isPresented in
                if !isPresented, store.selectedTab == .goals {
                    store.send(.tabSelected(.home))
                }
            }
        )
    }

    private var newFocusErrorBinding: Binding<Bool> {
        Binding(
            get: { newFocusErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    newFocusErrorMessage = nil
                }
            }
        )
    }

    private func handleOpenURL(_ url: URL) {
        guard let deepLink = RoutinaDeepLink(url: url) else { return }
        NSLog("Routina AppView deep link URL received: \(url.absoluteString)")
        openDeepLink(deepLink)
    }

    @MainActor
    private func handleDeepLinkNotification(_ notification: Notification) {
        guard let deepLink = RoutinaDeepLinkDispatcher.deepLink(from: notification) else { return }
        NSLog("Routina AppView deep link notification received")
        RoutinaDeepLinkDispatcher.markHandled(deepLink)
        openDeepLink(deepLink)
    }

    @MainActor
    @discardableResult
    private func handlePendingDeepLink() -> Bool {
        guard let deepLink = RoutinaDeepLinkDispatcher.consumePendingDeepLink() else { return false }
        openDeepLink(deepLink)
        return true
    }

    @MainActor
    private func handleLiveActivityContinuation(_ userActivity: NSUserActivity) {
        NSLog("Routina Live Activity SwiftUI continuation received: \(userActivity.activityType)")
        RoutinaActiveFocusOpenDispatcher.consumePendingRequest()
        handleActiveFocusOpenRequest()
    }

    @MainActor
    private func handleActiveFocusOpenRequest() {
        do {
            guard let deepLink = try activeFocusDeepLink() else { return }
            openDeepLink(deepLink)
        } catch {
            NSLog("Failed to resolve Live Activity deep link: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func handleActivationRouting() {
        if handlePendingDeepLink() {
            return
        }

        if RoutinaActiveFocusOpenDispatcher.consumePendingRequest() {
            handleActiveFocusOpenRequest()
        }
    }

    @MainActor
    private func openDeepLink(_ deepLink: RoutinaDeepLink) {
        switch deepLink {
        case .task, .goal, .note, .event, .sleep:
            presentedSprintFocusDeepLink = nil
        case let .sprint(sprintID):
            presentedSprintFocusDeepLink = SprintFocusDeepLinkPresentation(id: sprintID)
        }
        store.send(.openDeepLink(deepLink))
    }

    @MainActor
    private func activeFocusDeepLink(includeRecordedFallback: Bool = true) throws -> RoutinaDeepLink? {
        if let activityFocus = activeLiveActivityDeepLink() {
            return activityFocus.deepLink
        }

        let taskFocus = try activeTaskFocusDeepLink()
        let sprintFocus = try activeSprintFocusDeepLink()

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
    private func activeLiveActivityDeepLink() -> ActiveFocusDeepLink? {
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
        return deepLinks.sorted { $0.startedAt > $1.startedAt }.first
        #else
        return nil
        #endif
    }

    @MainActor
    private func activeTaskFocusDeepLink() throws -> ActiveFocusDeepLink? {
        let sessions = try modelContext.fetch(FetchDescriptor<FocusSession>())
        guard let session = sessions
            .filter({ $0.state == .active })
            .sorted(by: { ($0.startedAt ?? .distantPast) > ($1.startedAt ?? .distantPast) })
            .first
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
    private func activeSprintFocusDeepLink() throws -> ActiveFocusDeepLink? {
        let sessions = try modelContext.fetch(FetchDescriptor<SprintFocusSessionRecord>())
        guard let session = sessions
            .filter({ $0.stoppedAt == nil })
            .sorted(by: { $0.startedAt > $1.startedAt })
            .first
        else {
            return nil
        }

        return ActiveFocusDeepLink(
            deepLink: .sprint(session.sprintID),
            startedAt: session.startedAt
        )
    }
}

private enum IOSSearchPresentationPolicy {
    static let inputDebounce: Duration = .milliseconds(120)
}

private enum AppTabBarItem: Hashable {
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

private struct ActiveFocusDeepLink {
    let deepLink: RoutinaDeepLink
    let startedAt: Date
}

private struct SprintFocusDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
}

private enum NewTabAction: CaseIterable, Equatable, Hashable, Identifiable {
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

private extension AppColorScheme {
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

private struct NewActionListSheet: View {
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
