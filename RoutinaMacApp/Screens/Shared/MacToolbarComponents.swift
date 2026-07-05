import AppKit
import SwiftUI

struct MacToolbarIconButton: NSViewRepresentable {
    let title: String
    let systemImage: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let button = RoutinaMacToolbarIconButton(
            image: NSImage(systemSymbolName: systemImage, accessibilityDescription: title) ?? NSImage(),
            target: context.coordinator,
            action: #selector(Coordinator.performAction)
        )
        button.imagePosition = .imageOnly
        button.bezelStyle = .texturedRounded
        button.isBordered = true
        button.toolTip = title
        button.contentTintColor = .labelColor
        button.setButtonType(.momentaryPushIn)
        return button
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let button = nsView as? NSButton else {
            return
        }

        button.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        button.toolTip = title
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        private let action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func performAction() {
            action()
        }
    }
}

private final class RoutinaMacToolbarIconButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHidden, alphaValue > 0.01, bounds.contains(point) else {
            return nil
        }

        return self
    }
}

struct MacToolbarStatusBadge: View {
    let title: String
    let systemImage: String
    let tintColor: NSColor

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(Color(nsColor: tintColor))
        .padding(.leading, 4)
        .padding(.trailing, 8)
        .help(title)
    }
}
