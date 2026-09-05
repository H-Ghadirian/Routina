import AppKit
import ComposableArchitecture
import SwiftUI

struct TaskDetailToolbarContent: ToolbarContent {
    let store: StoreOf<TaskDetailFeature>
    let showsPrincipalToolbarTitle: Bool
    let isInlineEditPresented: Bool

    var body: some ToolbarContent {
        if showsPrincipalToolbarTitle {
            RoutinaMacFocusTimerToolbarItem()

            ToolbarItem(placement: .principal) {
                if isInlineEditPresented {
                    editTitle
                } else {
                    Text(store.routineEmoji)
                        .font(TaskDetailPlatformStyle.principalTitleFont)
                }
            }
        }
    }

    private var editTitle: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
            Text("Edit Task")
                .lineLimit(1)
        }
        .font(TaskDetailPlatformStyle.principalTitleFont)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .routinaGlassPill(tint: .accentColor, tintOpacity: 0.10, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }
}

enum TaskDetailOverflowMenuElement {
    case action(TaskDetailOverflowMenuAction)
    case separator
}

struct TaskDetailOverflowMenuAction {
    enum Role: Equatable {
        case standard
        case destructive
    }

    let title: String
    let systemImage: String
    var isEnabled = true
    var role: Role = .standard
    let action: () -> Void
}

@MainActor
struct TaskDetailOverflowMenuPresenter: NSViewRepresentable {
    let requestID: Int
    @Binding var isPresented: Bool
    let elements: [TaskDetailOverflowMenuElement]

    func makeNSView(context: Context) -> TaskDetailOverflowMenuAnchorView {
        TaskDetailOverflowMenuAnchorView()
    }

    func updateNSView(_ nsView: TaskDetailOverflowMenuAnchorView, context: Context) {
        let coordinator = context.coordinator
        coordinator.elements = elements
        let presentationBinding = $isPresented
        coordinator.setPresented = { isPresented in
            guard presentationBinding.wrappedValue != isPresented else { return }
            withAnimation(.easeInOut(duration: 0.12)) {
                presentationBinding.wrappedValue = isPresented
            }
        }

        guard requestID != coordinator.lastRequestID else { return }
        coordinator.lastRequestID = requestID
        guard requestID > 0 else { return }

        DispatchQueue.main.async {
            coordinator.presentMenu(from: nsView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        var elements: [TaskDetailOverflowMenuElement] = []
        var lastRequestID = 0
        var setPresented: ((Bool) -> Void)?

        private var actionHandlers: [() -> Void] = []
        private var isMenuPresented = false

        func presentMenu(from anchorView: NSView) {
            guard !isMenuPresented else { return }
            guard anchorView.window != nil else {
                setPresented?(false)
                return
            }

            isMenuPresented = true
            setPresented?(true)

            let menu = makeMenu()
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: anchorView.bounds.midX, y: anchorView.bounds.minY),
                in: anchorView
            )

            isMenuPresented = false
            setPresented?(false)
        }

        private func makeMenu() -> NSMenu {
            let menu = NSMenu()
            menu.autoenablesItems = false
            actionHandlers = []

            for element in elements {
                switch element {
                case .separator:
                    menu.addItem(.separator())

                case let .action(action):
                    let item = NSMenuItem(
                        title: action.title,
                        action: #selector(performAction(_:)),
                        keyEquivalent: ""
                    )
                    item.target = self
                    item.tag = actionHandlers.count
                    item.isEnabled = action.isEnabled
                    item.image = NSImage(
                        systemSymbolName: action.systemImage,
                        accessibilityDescription: action.title
                    )
                    if action.role == .destructive {
                        item.attributedTitle = NSAttributedString(
                            string: action.title,
                            attributes: [.foregroundColor: NSColor.systemRed]
                        )
                    }
                    actionHandlers.append(action.action)
                    menu.addItem(item)
                }
            }

            return menu
        }

        @objc private func performAction(_ sender: NSMenuItem) {
            guard actionHandlers.indices.contains(sender.tag) else { return }
            actionHandlers[sender.tag]()
        }
    }
}

final class TaskDetailOverflowMenuAnchorView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
