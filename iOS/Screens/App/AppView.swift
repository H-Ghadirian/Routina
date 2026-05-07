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
    @State private var searchText = ""
    @State private var presentedSprintFocusDeepLink: SprintFocusDeepLinkPresentation?
    @AppStorage(UserDefaultStringValueKey.appSettingAppColorScheme.rawValue, store: SharedDefaults.app)
    private var appColorSchemeRawValue = AppColorScheme.system.rawValue
    @AppStorage(UserDefaultStringValueKey.appSettingFastFilterTags.rawValue, store: SharedDefaults.app)
    private var fastFilterTagsRawValue = ""

    var body: some View {
        WithPerceptionTracking {
            let tabView = TabView(
                selection: Binding(
                    get: { store.selectedTab },
                    set: { store.send(.tabSelected($0)) }
                )
            ) {
                SwiftUI.Tab(Tab.home.rawValue, systemImage: "house", value: Tab.home) {
                    platformHomeView
                }

                SwiftUI.Tab(Tab.search.rawValue, systemImage: "magnifyingglass", value: Tab.search, role: .search) {
                    platformSearchHomeView(searchText: $searchText)
                }

                SwiftUI.Tab(Tab.goals.rawValue, systemImage: "target", value: Tab.goals) {
                    GoalsTCAView(
                        store: store.scope(state: \.goals, action: \.goals)
                    )
                }

                SwiftUI.Tab("Dones", systemImage: "clock.arrow.circlepath", value: Tab.timeline) {
                    TimelineView(
                        store: store.scope(state: \.timeline, action: \.timeline)
                    )
                }

                SwiftUI.Tab(Tab.stats.rawValue, systemImage: "chart.bar.xaxis", value: Tab.stats) {
                    StatsViewWrapper(
                        store: store.scope(state: \.stats, action: \.stats)
                    )
                }

                SwiftUI.Tab(Tab.settings.rawValue, systemImage: "gear", value: Tab.settings) {
                    SettingsTCAView(
                        store: store.scope(state: \.settings, action: \.settings)
                    )
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
                HomeTabFastFilterMenuBridge(
                    fastFilters: fastFilterTags,
                    selectedTags: store.home.selectedTags,
                    onSelect: { tag in
                        store.send(.homeFastFilterSelected(tag))
                    },
                    onClear: {
                        store.send(.home(.clearOptionalFilters))
                    }
                )
                .frame(width: 0, height: 0)
            }
            .sheet(item: $presentedSprintFocusDeepLink) { presentation in
                SprintFocusDeepLinkView(sprintID: presentation.id)
            }
        }
    }

    private var appColorScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorSchemeRawValue) ?? .system
    }

    private var fastFilterTags: [String] {
        FastFilterTags.decoded(from: fastFilterTagsRawValue)
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
        case .task:
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

private struct ActiveFocusDeepLink {
    let deepLink: RoutinaDeepLink
    let startedAt: Date
}

private struct SprintFocusDeepLinkPresentation: Identifiable, Equatable {
    let id: UUID
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

private struct HomeTabFastFilterMenuBridge: UIViewRepresentable {
    var fastFilters: [String]
    var selectedTags: Set<String>
    var onSelect: (String) -> Void
    var onClear: () -> Void

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
        context.coordinator.fastFilters = fastFilters
        context.coordinator.selectedTags = selectedTags
        context.coordinator.onSelect = onSelect
        context.coordinator.onClear = onClear

        DispatchQueue.main.async {
            context.coordinator.install(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var fastFilters: [String] = []
        var selectedTags: Set<String> = []
        var onSelect: (String) -> Void = { _ in }
        var onClear: () -> Void = {}

        private weak var installedTabBar: UITabBar?
        private weak var menuSourceButton: UIButton?
        private lazy var longPressGesture: UILongPressGestureRecognizer = {
            let gesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            return gesture
        }()

        func install(from view: UIView, attempt: Int = 0) {
            guard let tabBar = findTabBarController(from: view)?.tabBar else {
                guard attempt < 6 else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.install(from: view, attempt: attempt + 1)
                }
                return
            }

            if installedTabBar !== tabBar {
                uninstall()
                tabBar.addGestureRecognizer(longPressGesture)
                installedTabBar = tabBar
            }
        }

        func uninstall() {
            installedTabBar?.removeGestureRecognizer(longPressGesture)
            menuSourceButton?.removeFromSuperview()
            menuSourceButton = nil
            installedTabBar = nil
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard let tabBar = installedTabBar,
                  !fastFilters.isEmpty,
                  gesture.state == .began
            else {
                return
            }

            let location = gesture.location(in: tabBar)
            guard isHomeTabLocation(location, in: tabBar) else { return }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            presentMenu(from: tabBar)
        }

        private func presentMenu(from tabBar: UITabBar) {
            let sourceButton = menuSourceButton ?? makeMenuSourceButton(in: tabBar)
            menuSourceButton = sourceButton

            if let homeFrame = homeTabFrame(in: tabBar) {
                sourceButton.center = CGPoint(
                    x: max(homeFrame.minX + 12, tabBar.bounds.minX + 12),
                    y: tabBar.bounds.minY - 10
                )
            } else {
                sourceButton.center = CGPoint(
                    x: tabBar.bounds.minX + 12,
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
            var actions = fastFilters.map { tag in
                UIAction(
                    title: "#\(tag)",
                    image: UIImage(systemName: "tag"),
                    state: selectedTags.contains { RoutineTag.contains($0, in: [tag]) } ? .on : .off
                ) { [weak self] _ in
                    self?.onSelect(tag)
                }
            }

            if !selectedTags.isEmpty {
                actions.append(
                    UIAction(
                        title: "Clear Filters",
                        image: UIImage(systemName: "line.3.horizontal.decrease.circle")
                    ) { [weak self] _ in
                        self?.onClear()
                    }
                )
            }

            return UIMenu(title: "Fast Filters", children: actions)
        }

        private func isHomeTabLocation(_ location: CGPoint, in tabBar: UITabBar) -> Bool {
            if let homeTabFrame = homeTabFrame(in: tabBar) {
                return homeTabFrame.contains(location)
            }

            let itemCount = tabBar.items?.count ?? 0
            guard itemCount > 0, tabBar.bounds.width > 0 else { return false }

            let itemWidth = tabBar.bounds.width / CGFloat(itemCount)
            return location.x >= 0 && location.x <= itemWidth
        }

        private func homeTabFrame(in tabBar: UITabBar) -> CGRect? {
            guard let homeTabButton = homeTabButton(in: tabBar) else { return nil }
            return homeTabButton.convert(homeTabButton.bounds, to: tabBar)
        }

        private func homeTabButton(in tabBar: UITabBar) -> UIView? {
            tabBar.layoutIfNeeded()

            return tabBar.tabBarControls
                .filter { !$0.isHidden && $0.alpha > 0.01 && $0.bounds.width > 0 && $0.bounds.height > 0 }
                .sorted {
                    $0.convert($0.bounds, to: tabBar).minX < $1.convert($1.bounds, to: tabBar).minX
                }
                .first
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
