import AppKit
import Combine
import Foundation

@MainActor
final class RoutinaMacFocusTimerStatusBarController: NSObject {
    static let shared = RoutinaMacFocusTimerStatusBarController()

    private var statusItem: NSStatusItem?
    private weak var statusStore: RoutinaMacFocusTimerStatusStore?
    private var statusCancellable: AnyCancellable?
    private var displayTimer: Timer?
    private var currentStatus: RoutinaMacFocusTimerStatus = .inactive
    private var currentMenuKey: RoutinaMacFocusTimerMenuKey?
    private weak var runningTimeMenuItem: NSMenuItem?

    private override init() {
        super.init()
    }

    func configure(store: RoutinaMacFocusTimerStatusStore) {
        guard !AppEnvironment.isAutomatedTestMode else { return }

        statusStore = store
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }

        statusCancellable = store.statusUpdates.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }

        startDisplayTimerIfNeeded()
        updateStatusItem()
    }

    private func startDisplayTimerIfNeeded() {
        guard displayTimer == nil else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatusItem()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func updateStatusItem() {
        guard let statusItem,
              let button = statusItem.button
        else {
            return
        }

        let status = statusStore?.status ?? .inactive
        currentStatus = status
        let now = Date()
        let title = status.isActive ? status.menuBarTimeText(at: now) : "R"
        let font = status.isActive
            ? NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            : NSFont.systemFont(ofSize: 13, weight: .semibold)

        button.image = nil
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: font]
        )
        button.toolTip = status.isActive
            ? "\(status.kind?.displayTitle ?? "Focus Timer"): \(status.shortTitle)"
            : "Routina"

        let menuKey = RoutinaMacFocusTimerMenuKey(status: status)
        if menuKey != currentMenuKey {
            statusItem.menu = makeMenu(status: status, now: now)
            currentMenuKey = menuKey
        } else if status.isActive {
            runningTimeMenuItem?.title = "\(status.menuBarTimeText(at: now)) \(status.menuBarModeText(at: now))"
        }
    }

    private func makeMenu(status: RoutinaMacFocusTimerStatus, now: Date) -> NSMenu {
        let menu = NSMenu()
        runningTimeMenuItem = nil

        if status.isActive {
            let openTitle: String
            switch status.kind {
            case .sprint:
                openTitle = "Open Sprint"
            case .task:
                openTitle = "Open Task Details"
            case .tag:
                openTitle = "Tag Focus"
            case .unassigned, nil:
                openTitle = "Focus Timer"
            }
            let summaryItem = NSMenuItem(
                title: "\(openTitle): \(status.shortTitle)",
                action: status.deepLink == nil ? nil : #selector(openRunningFocus),
                keyEquivalent: ""
            )
            summaryItem.target = self
            summaryItem.isEnabled = status.deepLink != nil
            menu.addItem(summaryItem)

            let timeItem = NSMenuItem(
                title: "\(status.menuBarTimeText(at: now)) \(status.menuBarModeText(at: now))",
                action: nil,
                keyEquivalent: ""
            )
            timeItem.isEnabled = false
            menu.addItem(timeItem)
            runningTimeMenuItem = timeItem

            if status.supportsPauseResume {
                menu.addItem(menuItem(
                    title: status.isPaused ? "Resume Timer" : "Pause Timer",
                    action: #selector(togglePauseResumeFocus)
                ))
            }
            menu.addItem(.separator())
        }

        menu.addItem(menuItem(title: "Add Task", action: #selector(addTask)))
        menu.addItem(menuItem(title: "Open Routina", action: #selector(openRoutina)))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        return menu
    }

    private func menuItem(
        title: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func addTask() {
        RoutinaMacWindowRouter.shared.openHomeAndActivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            NotificationCenter.default.post(name: .routinaMacOpenAddTask, object: nil)
        }
    }

    @objc private func openRoutina() {
        RoutinaMacWindowRouter.shared.openHomeAndActivate()
    }

    @objc private func openRunningFocus() {
        guard let deepLink = currentStatus.deepLink else {
            openRoutina()
            return
        }

        RoutinaMacWindowRouter.shared.openHomeAndActivate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            RoutinaDeepLinkDispatcher.open(deepLink)
        }
    }

    @objc private func togglePauseResumeFocus() {
        guard let statusStore else { return }

        do {
            if try statusStore.togglePauseResume(for: currentStatus) {
                updateStatusItem()
            }
        } catch {
            NSLog("Failed to toggle focus timer pause state from menu bar: \(error.localizedDescription)")
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}

private struct RoutinaMacFocusTimerMenuKey: Equatable {
    var id: UUID?
    var targetID: UUID?
    var kind: RoutinaMacFocusTimerStatus.Kind?
    var title: String
    var isActive: Bool
    var isPaused: Bool

    init(status: RoutinaMacFocusTimerStatus) {
        id = status.id
        targetID = status.targetID
        kind = status.kind
        title = status.title
        isActive = status.isActive
        isPaused = status.isPaused
    }
}
