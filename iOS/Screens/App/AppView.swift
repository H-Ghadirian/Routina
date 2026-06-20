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
    @Query(sort: \SleepSession.startedAt, order: .reverse) private var sleepSessions: [SleepSession]
    @State private var searchText = ""
    @State private var moreDestination: AppMoreDestination?
    @State private var presentedSprintFocusDeepLink: SprintFocusDeepLinkPresentation?
    @State private var isNewActionListPresented = false
    @State private var pendingNewTabAction: NewTabAction?
    @State private var presentedNewActionSheet: NewActionSheet?
    @State private var isNewSheetSleepConfirmationPresented = false
    @State private var newSheetSleepWarningMessage: String?
    @State private var timelinePresentationID = UUID()
    @AppStorage(UserDefaultStringValueKey.appSettingAppColorScheme.rawValue, store: SharedDefaults.app)
    private var appColorSchemeRawValue = AppColorScheme.system.rawValue
    @AppStorage(UserDefaultBoolValueKey.appSettingSleepHomeMenuEnabled.rawValue, store: SharedDefaults.app)
    private var isSleepNewSheetEnabled = true
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
        platformSearchHomeView(searchText: $searchText)
    }

    if !usesCompactMoreTab && isGoalsTabEnabled {
        SwiftUI.Tab(Tab.goals.rawValue, systemImage: "target", value: AppTabBarItem.goals) {
            GoalsTCAView(
                store: store.scope(state: \.goals, action: \.goals)
            )
        }
    }

    SwiftUI.Tab("New", systemImage: "plus", value: AppTabBarItem.addTask) {
        Color.clear
    }

    SwiftUI.Tab(Tab.timeline.rawValue, systemImage: "clock.arrow.circlepath", value: AppTabBarItem.timeline) {
        TimelineView(
            store: store.scope(state: \.timeline, action: \.timeline),
            presentationID: timelinePresentationID
        )
    }

    if usesCompactMoreTab {
        SwiftUI.Tab(Tab.more.rawValue, systemImage: "ellipsis.circle", value: AppTabBarItem.more) {
            AppMoreNavigationView(
                destination: $moreDestination,
                selectedTab: store.selectedTab,
                goalsStore: store.scope(state: \.goals, action: \.goals),
                statsStore: store.scope(state: \.stats, action: \.stats),
                settingsStore: store.scope(state: \.settings, action: \.settings),
                showGoalsTab: isGoalsTabEnabled,
                onSelectTab: { store.send(.tabSelected($0)) }
            )
        }
    } else {
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
}
Group {
    if store.selectedTab == .search {
        AppLockGate {
            tabView
                .searchable(text: $searchText, prompt: "Search routines and todos")
                .onReceive(NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)) { _ in
                    PlatformSupport.applyAppIcon(.persistedSelection)
                    store.send(.cloudSettingsChanged)
                }
                .task {
                    store.send(.onAppear)
                    handlePendingDeepLink()
                }
        }
    } else {
        AppLockGate {
            tabView
                .onReceive(NotificationCenter.default.publisher(for: CloudSettingsKeyValueSync.didChangeNotification)) { _ in
                    PlatformSupport.applyAppIcon(.persistedSelection)
                    store.send(.cloudSettingsChanged)
                }
                .task {
                    store.send(.onAppear)
                    handlePendingDeepLink()
                }
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
        actions: availableNewTabActions,
        onSelect: queueNewTabAction
    )
    .presentationDetents([.height(newActionListSheetHeight)])
    .presentationDragIndicator(.visible)
}
.sheet(item: $presentedNewActionSheet) { sheet in
    newActionSheetContent(for: sheet)
}
.alert("Stop focus timer?", isPresented: $isNewSheetSleepConfirmationPresented) {
    Button("Start Sleep", role: .destructive) {
        startSleepFromNewSheet()
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text(newSheetSleepWarningMessage ?? "Starting sleep mode will stop the current focus timer.")
}
.awayModeGate()
.sleepModeGate()
    }

    private var appColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRawValue) ?? .system
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
        if usesCompactMoreTab,
           store.selectedTab == .goals || store.selectedTab == .stats || store.selectedTab == .settings {
            return .more
        }

        if !usesCompactMoreTab,
           store.selectedTab == .goals && !isGoalsTabEnabled {
            return .home
        }

        if !usesCompactMoreTab, store.selectedTab == .more {
            return .settings
        }

        return AppTabBarItem(tab: store.selectedTab)
    }

    private var usesCompactMoreTab: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    private var isNewSheetSleepActionEnabled: Bool {
        isSleepNewSheetEnabled && sleepSessions.first(where: { $0.endedAt == nil }) == nil
    }

    private var availableNewTabActions: [NewTabAction] {
        NewTabAction.creationActions + NewTabAction.sessionActions.filter { action in
            action != .sleep || isNewSheetSleepActionEnabled
        }
    }

    private var newActionListSheetHeight: CGFloat {
        min(CGFloat(availableNewTabActions.count) * 54 + 92, 520)
    }

    private func selectTab(_ tab: AppTabBarItem) {
        if tab == .addTask {
            isNewActionListPresented = true
            return
        }

        if usesCompactMoreTab, tab == .more, selectedTabForCurrentLayout == .more {
            moreDestination = nil
        }

        guard let appTab = tab.appTab else { return }
        store.send(.tabSelected(appTab))
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
        switch action {
        case .event:
            presentedNewActionSheet = .event
        case .emotion:
            presentedNewActionSheet = .emotion
        case .note:
            presentedNewActionSheet = .note
        case .goal:
            openNewGoal()
        case .task:
            openNewTask()
        case .checkIn:
            presentedNewActionSheet = .checkIn
        case .away:
            presentedNewActionSheet = .away
        case .sleep:
            requestSleepFromNewSheet()
        }
    }

    private func openNewTask() {
        presentedNewActionSheet = nil
        moreDestination = nil
        store.send(.tabSelected(.home))
        store.send(.home(.setSmartAddTaskSheet(true)))
    }

    private func openNewGoal() {
        presentedNewActionSheet = nil
        if usesCompactMoreTab {
            moreDestination = .goals
        } else {
            moreDestination = nil
        }
        store.send(.tabSelected(.goals))
        store.send(.goals(.addGoalTapped))
    }

    @ViewBuilder
    private func newActionSheetContent(for sheet: NewActionSheet) -> some View {
        switch sheet {
        case .event:
            RoutineEventEditorView()
        case .emotion:
            EmotionLogEditorView()
        case .note:
            RoutineNoteEditorView()
        case .checkIn:
            PlaceCheckInMapSheet()
        case .away:
            AwaySessionStartSheet()
        }
    }

    @MainActor
    private func requestSleepFromNewSheet() {
        do {
            if let warningMessage = try SleepSessionSupport.activeFocusTimerWarningMessage(in: modelContext) {
                newSheetSleepWarningMessage = warningMessage
                isNewSheetSleepConfirmationPresented = true
                return
            }

            startSleepFromNewSheet()
        } catch {
            NSLog("Failed to check active focus before New sheet sleep start: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func startSleepFromNewSheet() {
        do {
            _ = try SleepSessionSupport.startSleep(in: modelContext)
            newSheetSleepWarningMessage = nil
            isNewSheetSleepConfirmationPresented = false
        } catch {
            NSLog("Failed to start sleep session from New sheet: \(error.localizedDescription)")
        }
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
        guard !session.isUnassigned else {
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

private enum AppTabBarItem: Hashable {
    case home
    case search
    case goals
    case addTask
    case timeline
    case stats
    case settings
    case more

    init(tab: Tab) {
        switch tab {
        case .home:
            self = .home
        case .search:
            self = .search
        case .goals:
            self = .goals
        case .timeline:
            self = .timeline
        case .stats:
            self = .stats
        case .settings:
            self = .settings
        case .more:
            self = .more
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
        case .timeline:
            return .timeline
        case .stats:
            return .stats
        case .settings:
            return .settings
        case .more:
            return .more
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

private enum NewActionSheet: String, Identifiable {
    case event
    case emotion
    case note
    case checkIn
    case away

    var id: String { rawValue }
}

private enum NewTabAction: CaseIterable, Equatable, Hashable, Identifiable {
    case event
    case emotion
    case note
    case goal
    case task
    case checkIn
    case away
    case sleep

    static let creationActions: [NewTabAction] = [.event, .emotion, .note, .goal, .task]
    static let sessionActions: [NewTabAction] = [.checkIn, .away, .sleep]

    var id: Self { self }

    var title: String {
        switch self {
        case .event:
            return "Event"
        case .emotion:
            return "Emotion"
        case .note:
            return "Note"
        case .goal:
            return "Goal"
        case .task:
            return "Task"
        case .checkIn:
            return "Check In"
        case .away:
            return "Away"
        case .sleep:
            return "Going to sleep"
        }
    }

    var systemImage: String {
        switch self {
        case .event:
            return "calendar.badge.plus"
        case .emotion:
            return "face.smiling"
        case .note:
            return "note.text"
        case .goal:
            return "target"
        case .task:
            return "checklist"
        case .checkIn:
            return "mappin.and.ellipse"
        case .away:
            return "lock.shield.fill"
        case .sleep:
            return "bed.double.fill"
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

private enum AppMoreDestination: Hashable {
    case goals
    case stats
    case settings
}

private struct AppMoreNavigationView: View {
    @Binding var destination: AppMoreDestination?
    let selectedTab: Tab
    let goalsStore: StoreOf<GoalsFeature>
    let statsStore: StoreOf<StatsFeature>
    let settingsStore: StoreOf<SettingsFeature>
    let showGoalsTab: Bool
    let onSelectTab: (Tab) -> Void

    var body: some View {
        NavigationStack {
            moreList
                .navigationDestination(isPresented: isDestinationPresented(.goals)) {
                    destinationView(for: .goals)
                }
                .navigationDestination(isPresented: isDestinationPresented(.stats)) {
                    destinationView(for: .stats)
                }
                .navigationDestination(isPresented: isDestinationPresented(.settings)) {
                    destinationView(for: .settings)
            }
        }
        .onAppear {
            restoreSelectedMoreDestinationIfNeeded()
        }
        .onChange(of: selectedTab) { _, tab in
            restoreSelectedMoreDestinationIfNeeded(for: tab)
        }
        .onChange(of: destination) { _, destination in
            if destination == nil,
               (showGoalsTab && selectedTab == .goals) || selectedTab == .stats || selectedTab == .settings {
                onSelectTab(.more)
            }
        }
    }

    private var moreList: some View {
        List {
            Section {
                if showGoalsTab {
                    moreButton(destination: .goals) {
                        SettingsNavigationRow(
                            icon: "target",
                            tint: .blue,
                            title: Tab.goals.rawValue,
                            subtitle: "Outcomes, sub-goals, and linked tasks"
                        )
                    }
                }

                moreButton(destination: .stats) {
                    SettingsNavigationRow(
                        icon: "chart.bar.xaxis",
                        tint: .indigo,
                        title: Tab.stats.rawValue,
                        subtitle: "Completion, focus, tags, and trends"
                    )
                }

                moreButton(destination: .settings) {
                    SettingsNavigationRow(
                        icon: "gear",
                        tint: .gray,
                        title: Tab.settings.rawValue,
                        subtitle: "Preferences, data, tags, places, and support"
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Tab.more.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func moreButton<Label: View>(
        destination: AppMoreDestination,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            self.destination = destination
        } label: {
            HStack(spacing: 8) {
                label()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(for destination: AppMoreDestination) -> some View {
        switch destination {
        case .goals:
            GoalsTCAView(store: goalsStore)
                .onAppear {
                    selectTabAfterNavigationGesture(.goals)
                }
        case .stats:
            StatsView(
                store: statsStore,
                ownsCompactNavigationStack: false
            )
            .onAppear {
                selectTabAfterNavigationGesture(.stats)
            }
        case .settings:
            SettingsTCAView(
                store: settingsStore,
                ownsCompactNavigationStack: false
            )
            .onAppear {
                selectTabAfterNavigationGesture(.settings)
            }
        }
    }

    private func restoreSelectedMoreDestinationIfNeeded(for tab: Tab? = nil) {
        guard destination == nil else { return }

        switch tab ?? selectedTab {
        case .goals where showGoalsTab:
            destination = .goals
        case .stats:
            destination = .stats
        case .settings:
            destination = .settings
        default:
            break
        }
    }

    private func isDestinationPresented(_ candidate: AppMoreDestination) -> Binding<Bool> {
        Binding(
            get: {
                destination == candidate
            },
            set: { isPresented in
                if isPresented {
                    destination = candidate
                } else if destination == candidate {
                    destination = nil
                }
            }
        )
    }

    private func selectTabAfterNavigationGesture(_ tab: Tab) {
        DispatchQueue.main.async {
            onSelectTab(tab)
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
