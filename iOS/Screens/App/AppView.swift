import SwiftUI
#if canImport(ActivityKit)
import ActivityKit
#endif
import ComposableArchitecture
import SwiftData
import UIKit
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
    @State private var presentedNewActionSheet: NewActionSheet?
    @State private var isNewMenuSleepConfirmationPresented = false
    @State private var newMenuSleepWarningMessage: String?
    @AppStorage(UserDefaultStringValueKey.appSettingAppColorScheme.rawValue, store: SharedDefaults.app)
    private var appColorSchemeRawValue = AppColorScheme.system.rawValue
    @AppStorage(UserDefaultBoolValueKey.appSettingSleepHomeMenuEnabled.rawValue, store: SharedDefaults.app)
    private var isSleepNewMenuEnabled = true

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

    if !usesCompactMoreTab {
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
            store: store.scope(state: \.timeline, action: \.timeline)
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
.background {
    NewTabContextMenuBridge(
        newTabIndex: newTabIndex,
        isSleepActionEnabled: isNewMenuSleepActionEnabled,
        onSelect: performNewTabAction
    )
    .frame(width: 0, height: 0)
}
.sheet(item: $presentedSprintFocusDeepLink) { presentation in
    SprintFocusDeepLinkView(sprintID: presentation.id)
}
.sheet(item: $presentedNewActionSheet) { sheet in
    newActionSheetContent(for: sheet)
}
.alert("Stop focus timer?", isPresented: $isNewMenuSleepConfirmationPresented) {
    Button("Start Sleep", role: .destructive) {
        startSleepFromNewMenu()
    }
    Button("Cancel", role: .cancel) {}
} message: {
    Text(newMenuSleepWarningMessage ?? "Starting sleep mode will stop the current focus timer.")
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

        if !usesCompactMoreTab, store.selectedTab == .more {
            return .settings
        }

        return AppTabBarItem(tab: store.selectedTab)
    }

    private var usesCompactMoreTab: Bool {
        horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    private var newTabIndex: Int {
        usesCompactMoreTab ? 2 : 3
    }

    private var isNewMenuSleepActionEnabled: Bool {
        isSleepNewMenuEnabled && sleepSessions.first(where: { $0.endedAt == nil }) == nil
    }

    private func selectTab(_ tab: AppTabBarItem) {
        if tab == .addTask {
            openNewTask()
            return
        }

        if usesCompactMoreTab, tab == .more, selectedTabForCurrentLayout == .more {
            moreDestination = nil
        }

        guard let appTab = tab.appTab else { return }
        store.send(.tabSelected(appTab))
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
            requestSleepFromNewMenu()
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
    private func requestSleepFromNewMenu() {
        do {
            if let warningMessage = try SleepSessionSupport.activeFocusTimerWarningMessage(in: modelContext) {
                newMenuSleepWarningMessage = warningMessage
                isNewMenuSleepConfirmationPresented = true
                return
            }

            startSleepFromNewMenu()
        } catch {
            NSLog("Failed to check active focus before New menu sleep start: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func startSleepFromNewMenu() {
        do {
            _ = try SleepSessionSupport.startSleep(in: modelContext)
            newMenuSleepWarningMessage = nil
            isNewMenuSleepConfirmationPresented = false
        } catch {
            NSLog("Failed to start sleep session from New menu: \(error.localizedDescription)")
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
        case .task, .goal, .note, .sleep:
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

private enum NewTabAction: CaseIterable, Equatable {
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
            if destination == nil, selectedTab == .goals || selectedTab == .stats || selectedTab == .settings {
                onSelectTab(.more)
            }
        }
    }

    private var moreList: some View {
        List {
            Section {
                moreButton(destination: .goals) {
                    SettingsNavigationRow(
                        icon: "target",
                        tint: .blue,
                        title: Tab.goals.rawValue,
                        subtitle: "Outcomes, sub-goals, and linked tasks"
                    )
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
        case .goals:
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

private struct NewTabContextMenuBridge: UIViewRepresentable {
    var newTabIndex: Int
    var isSleepActionEnabled: Bool
    var onSelect: (NewTabAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        coordinator.newTabIndex = newTabIndex
        coordinator.isSleepActionEnabled = isSleepActionEnabled
        coordinator.onSelect = onSelect

        DispatchQueue.main.async { [weak uiView] in
            guard let uiView else { return }
            coordinator.install(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.deactivate()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var newTabIndex = 2
        var isSleepActionEnabled = false
        var onSelect: (NewTabAction) -> Void = { _ in }

        private weak var installedTabBar: UITabBar?
        private weak var menuSourceButton: UIButton?
        private var longPressGesture: UILongPressGestureRecognizer?
        private var isActive = true

        deinit {
            MainActor.assumeIsolated {
                uninstall()
            }
        }

        func deactivate() {
            isActive = false
            uninstall()
        }

        func install(from view: UIView, attempt: Int = 0) {
            guard isActive else { return }

            guard let tabBar = findTabBarController(from: view)?.tabBar else {
                guard attempt < 6 else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.install(from: view, attempt: attempt + 1)
                }
                return
            }

            if installedTabBar !== tabBar || longPressGesture == nil {
                uninstall()
                let gesture = makeLongPressGesture()
                tabBar.addGestureRecognizer(gesture)
                longPressGesture = gesture
                installedTabBar = tabBar
            }
        }

        func uninstall() {
            if let longPressGesture {
                longPressGesture.delegate = nil
                longPressGesture.removeTarget(self, action: #selector(handleLongPress(_:)))
                installedTabBar?.removeGestureRecognizer(longPressGesture)
            }

            menuSourceButton?.removeFromSuperview()
            menuSourceButton = nil
            longPressGesture = nil
            installedTabBar = nil
        }

        private func makeLongPressGesture() -> UILongPressGestureRecognizer {
            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let tabBar = installedTabBar,
                  gesture.state == .began
            else {
                return
            }

            let location = gesture.location(in: tabBar)
            guard isNewTabLocation(location, in: tabBar) else { return }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            presentMenu(from: tabBar)
        }

        private func presentMenu(from tabBar: UITabBar) {
            let sourceButton = menuSourceButton ?? makeMenuSourceButton(in: tabBar)
            menuSourceButton = sourceButton

            if let newFrame = newTabFrame(in: tabBar) {
                sourceButton.center = CGPoint(
                    x: newFrame.midX,
                    y: tabBar.bounds.minY - 10
                )
            } else {
                sourceButton.center = CGPoint(
                    x: fallbackNewTabMidX(in: tabBar),
                    y: tabBar.bounds.minY - 10
                )
            }

            sourceButton.menu = makeMenu()
            sourceButton.showsMenuAsPrimaryAction = true
            sourceButton.performPrimaryAction()
        }

        private func makeMenuSourceButton(in tabBar: UITabBar) -> UIButton {
            let button = UIButton(type: .system)
            button.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
            button.alpha = 0.01
            button.isAccessibilityElement = false
            tabBar.addSubview(button)
            return button
        }

        private func makeMenu() -> UIMenu {
            let creationMenu = UIMenu(
                title: "",
                options: .displayInline,
                children: NewTabAction.creationActions.map { menuAction(for: $0) }
            )

            var sessionActions = NewTabAction.sessionActions
            if !isSleepActionEnabled {
                sessionActions.removeAll { $0 == .sleep }
            }

            let sessionMenu = UIMenu(
                title: "",
                options: .displayInline,
                children: sessionActions.map { menuAction(for: $0) }
            )

            return UIMenu(title: "New", children: [creationMenu, sessionMenu])
        }

        private func menuAction(for action: NewTabAction) -> UIAction {
            UIAction(
                title: action.title,
                image: UIImage(systemName: action.systemImage)
            ) { [weak self] _ in
                self?.onSelect(action)
            }
        }

        private func isNewTabLocation(_ location: CGPoint, in tabBar: UITabBar) -> Bool {
            if let newTabFrame = newTabFrame(in: tabBar) {
                return newTabFrame.contains(location)
            }

            let itemCount = tabBar.items?.count ?? 0
            guard itemCount > 0, tabBar.bounds.width > 0 else { return false }

            let itemWidth = tabBar.bounds.width / CGFloat(itemCount)
            let minX = itemWidth * CGFloat(min(newTabIndex, itemCount - 1))
            let maxX = minX + itemWidth
            return location.x >= minX && location.x <= maxX
        }

        private func newTabFrame(in tabBar: UITabBar) -> CGRect? {
            guard let newTabButton = newTabButton(in: tabBar) else { return nil }
            return newTabButton.convert(newTabButton.bounds, to: tabBar)
        }

        private func newTabButton(in tabBar: UITabBar) -> UIView? {
            tabBar.layoutIfNeeded()

            let controls = tabBar.tabBarControls
                .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 0 && $0.bounds.height > 0 }
                .sorted {
                    $0.convert($0.bounds, to: tabBar).minX < $1.convert($1.bounds, to: tabBar).minX
                }

            guard controls.indices.contains(newTabIndex) else { return nil }
            return controls[newTabIndex]
        }

        private func fallbackNewTabMidX(in tabBar: UITabBar) -> CGFloat {
            let itemCount = tabBar.items?.count ?? 0
            guard itemCount > 0, tabBar.bounds.width > 0 else {
                return tabBar.bounds.midX
            }

            let safeIndex = min(newTabIndex, itemCount - 1)
            let itemWidth = tabBar.bounds.width / CGFloat(itemCount)
            return itemWidth * CGFloat(safeIndex) + itemWidth / 2
        }

        private func findTabBarController(from view: UIView) -> UITabBarController? {
            var responder: UIResponder? = view
            while let current = responder {
                if let tabBarController = current as? UITabBarController {
                    return tabBarController
                }
                responder = current.next
            }

            return view.window?.rootViewController?.firstDescendant(of: UITabBarController.self)
        }
    }
}

private extension UIView {
    var tabBarControls: [UIControl] {
        subviews.flatMap { subview -> [UIControl] in
            var controls = subview.tabBarControls
            if let control = subview as? UIControl {
                controls.append(control)
            }
            return controls
        }
    }
}

private extension UIViewController {
    func firstDescendant<T: UIViewController>(of type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }

        for child in children {
            if let match = child.firstDescendant(of: type) {
                return match
            }
        }

        if let presentedViewController,
           let match = presentedViewController.firstDescendant(of: type) {
            return match
        }

        return nil
    }
}
