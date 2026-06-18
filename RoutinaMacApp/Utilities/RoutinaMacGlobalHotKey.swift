import AppKit
import Carbon
import Foundation
import OSLog

private let routinaMacWindowLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "RoutinaMac",
    category: "Windowing"
)

@MainActor
final class RoutinaMacWindowRouter {
    static let shared = RoutinaMacWindowRouter()

    var openHomeWindow: (() -> Void)?
    var openFallbackHomeWindow: (() -> Void)?
    private var isHomeOpenPending = false

    private init() {}

    func installHomeWindowOpener(_ opener: @escaping () -> Void) {
        openHomeWindow = opener
        routinaMacWindowLogger.info("Installed SwiftUI home window opener")
        guard isHomeOpenPending else { return }
        isHomeOpenPending = false
        openHomeAndActivate()
    }

    func installFallbackHomeWindowOpener(_ opener: @escaping () -> Void) {
        openFallbackHomeWindow = opener
        routinaMacWindowLogger.info("Installed AppKit fallback home window opener")
    }

    func requestHomeOpenAndActivate() {
        if openHomeWindow == nil {
            isHomeOpenPending = true
            routinaMacWindowLogger.info("Requested home open before SwiftUI opener was ready; app windows: \(NSApplication.shared.windows.count, privacy: .public)")
            activateHomeWindow()
            return
        }
        routinaMacWindowLogger.info("Requested home open; app windows: \(NSApplication.shared.windows.count, privacy: .public)")
        openHomeAndActivate()
    }

    func openHomeAndActivate() {
        NSApplication.shared.setActivationPolicy(.regular)

        let shouldRequestSwiftUIWindow = !hasVisibleAppWindow
        if shouldRequestSwiftUIWindow {
            if let openHomeWindow {
                routinaMacWindowLogger.info("Requesting SwiftUI home window")
                openHomeWindow()
            } else {
                routinaMacWindowLogger.info("Using immediate AppKit fallback because SwiftUI opener is not ready")
                openFallbackHomeWindow?()
            }
        }

        activateHomeWindow()

        DispatchQueue.main.async {
            if self.openHomeWindow == nil && !self.isHomeOpenPending && !self.hasVisibleAppWindow {
                routinaMacWindowLogger.info("Using next-run-loop AppKit fallback because no visible app window exists")
                self.openFallbackHomeWindow?()
            }
            self.activateHomeWindow()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if self.openHomeWindow == nil && !self.isHomeOpenPending && !self.hasVisibleAppWindow {
                routinaMacWindowLogger.info("Using delayed AppKit fallback because no visible app window exists")
                self.openFallbackHomeWindow?()
            }
            self.activateHomeWindow()
        }
    }

    func activateHomeWindow() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.unhide(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: .activateAllWindows)
        focusVisibleWindow()
        DispatchQueue.main.async {
            self.focusVisibleWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.focusVisibleWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.focusVisibleWindow()
        }
    }

    private func focusVisibleWindow() {
        let window = visibleAppWindow ?? NSApplication.shared.windows.first { isAppContentWindow($0) }
        window?.deminiaturize(nil)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.makeMain()
    }

    private var hasVisibleAppWindow: Bool {
        visibleAppWindow != nil
    }

    private var visibleAppWindow: NSWindow? {
        NSApplication.shared.windows.first { window in
            isAppContentWindow(window)
                && window.isVisible
                && !window.isMiniaturized
        }
    }

    private func isAppContentWindow(_ window: NSWindow) -> Bool {
        let className = String(describing: type(of: window))
        guard !className.contains("StatusBar"),
              !className.contains("Menu"),
              !className.contains("Popover")
        else {
            return false
        }

        return window.canBecomeKey
            && window.frame.width >= 300
            && window.frame.height >= 300
    }
}

@MainActor
final class RoutinaMacGlobalHotKeyManager {
    static let shared = RoutinaMacGlobalHotKeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var defaultsObserver: NSObjectProtocol?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x52544b31), id: 1)

    private init() {}

    func startQuickAddHotKey() {
        if defaultsObserver == nil {
            defaultsObserver = NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: SharedDefaults.app,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.registerQuickAddHotKey()
                }
            }
        }

        registerQuickAddHotKey()
    }

    func registerQuickAddHotKey() {
        unregisterHotKey()

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr,
                  hotKeyID.signature == OSType(0x52544b31),
                  hotKeyID.id == 1
            else {
                return noErr
            }

            DispatchQueue.main.async {
                RoutinaMacWindowRouter.shared.openHomeAndActivate()
                NotificationCenter.default.post(name: .routinaMacOpenQuickAdd, object: nil)
            }

            return noErr
        }

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )

        guard handlerStatus == noErr else {
            NSLog("Failed to install Routina global hotkey handler: \(handlerStatus)")
            return
        }

        let shortcut = MacQuickAddShortcut.stored()
        let registerStatus = RegisterEventHotKey(
            shortcut.carbonKeyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if registerStatus != noErr {
            NSLog("Failed to register Routina global hotkey: \(registerStatus)")
            unregister()
        }
    }

    func unregister() {
        unregisterHotKey()

        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}
