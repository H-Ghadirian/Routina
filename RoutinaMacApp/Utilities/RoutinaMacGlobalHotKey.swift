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
    private let hotKeyID = EventHotKeyID(signature: OSType(0x52544b31), id: 1)

    private init() {}

    func registerAddTaskHotKey() {
        guard hotKeyRef == nil else { return }

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
                NotificationCenter.default.post(name: .routinaMacOpenAddTask, object: nil)
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

        let modifiers = UInt32(optionKey | cmdKey)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_N),
            modifiers,
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
