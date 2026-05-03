import AppKit
import Carbon
import Foundation

@MainActor
final class RoutinaMacWindowRouter {
    static let shared = RoutinaMacWindowRouter()

    var openHomeWindow: (() -> Void)?

    private init() {}

    func openHomeAndActivate() {
        openHomeWindow?()
        NSApplication.shared.activate(ignoringOtherApps: true)
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
