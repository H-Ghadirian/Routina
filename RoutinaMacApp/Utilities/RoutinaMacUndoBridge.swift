import AppKit
import SwiftData
import SwiftUI

@MainActor
final class RoutinaMacUndoCenter {
    static let shared = RoutinaMacUndoCenter()

    private var mainContext: ModelContext?
    private var currentUndoManager: UndoManager?
    private var observedUndoManagerIDs: Set<ObjectIdentifier> = []
    private var undoRedoObserverTokens: [NSObjectProtocol] = []

    private init() {}

    func configure(mainContext: ModelContext, undoManager: UndoManager?) {
        guard let undoManager else { return }

        self.mainContext = mainContext
        currentUndoManager = undoManager
        prepareContext(mainContext)
        observeUndoRedo(on: undoManager)

        RoutinaUndoSupport.configure(
            undoManagerProvider: { [weak self] in
                self?.currentUndoManager
            },
            contextPreparer: { [weak self] context in
                self?.prepareContext(context)
            }
        )
    }

    private func prepareContext(_ context: ModelContext) {
        context.undoManager = currentUndoManager
    }

    private func observeUndoRedo(on undoManager: UndoManager) {
        let id = ObjectIdentifier(undoManager)
        guard observedUndoManagerIDs.insert(id).inserted else { return }

        for name in [Notification.Name.NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange] {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: undoManager,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.saveAfterUndoRedo()
                }
            }
            undoRedoObserverTokens.append(token)
        }
    }

    private func saveAfterUndoRedo() {
        guard let mainContext else { return }

        do {
            try mainContext.save()
            NotificationCenter.default.postRoutineDidUpdate()
        } catch {
            mainContext.rollback()
            NSLog("RoutinaMacUndoCenter: failed to save undo/redo changes: \(error.localizedDescription)")
        }
    }
}

struct RoutinaMacUndoBridge: NSViewRepresentable {
    let persistence: PersistenceController

    func makeNSView(context: Context) -> RoutinaMacUndoBridgeView {
        let view = RoutinaMacUndoBridgeView()
        view.persistence = persistence
        return view
    }

    func updateNSView(_ view: RoutinaMacUndoBridgeView, context: Context) {
        view.persistence = persistence
        view.installIfPossible()
    }
}

final class RoutinaMacUndoBridgeView: NSView {
    var persistence: PersistenceController?

    private weak var observedWindow: NSWindow?
    private let windowObservers = RoutinaMacNotificationObserverBag()

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        installIfPossible()
        updateWindowObservers()
    }

    func installIfPossible() {
        MainActor.assumeIsolated {
            guard let persistence,
                  let undoManager = window?.undoManager
            else { return }

            RoutinaMacUndoCenter.shared.configure(
                mainContext: persistence.container.mainContext,
                undoManager: undoManager
            )
        }
    }

    private func updateWindowObservers() {
        guard observedWindow !== window else { return }

        removeWindowObservers()
        observedWindow = window

        guard let window else { return }

        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification] {
            let token = NotificationCenter.default.addObserver(
                forName: name,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.installIfPossible()
                }
            }
            windowObservers.append(token)
        }
    }

    private func removeWindowObservers() {
        windowObservers.removeAll()
    }
}

private final class RoutinaMacNotificationObserverBag {
    private var tokens: [NSObjectProtocol] = []

    deinit {
        removeAll()
    }

    func append(_ token: NSObjectProtocol) {
        tokens.append(token)
    }

    func removeAll() {
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
        }
        tokens.removeAll()
    }
}
