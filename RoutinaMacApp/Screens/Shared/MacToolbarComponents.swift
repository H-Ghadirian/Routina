import AppKit
import SwiftUI

struct MacToolbarIconButton: NSViewRepresentable {
    let title: String
    let systemImage: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSView {
        let button = NSButton(
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

struct MacToolbarStatusBadge: NSViewRepresentable {
    let title: String
    let systemImage: String
    let tintColor: NSColor

    func makeNSView(context: Context) -> NSView {
        let imageView = NSImageView()
        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        imageView.contentTintColor = tintColor

        let textField = NSTextField(labelWithString: title)
        textField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        textField.textColor = tintColor
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentHuggingPriority(.required, for: .horizontal)

        let stackView = NSStackView(views: [imageView, textField])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 5
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        stackView.setContentHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        update(stackView: stackView, imageView: imageView, textField: textField)
        return stackView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let stackView = nsView as? NSStackView,
              stackView.views.count == 2,
              let imageView = stackView.views[0] as? NSImageView,
              let textField = stackView.views[1] as? NSTextField
        else {
            return
        }

        update(stackView: stackView, imageView: imageView, textField: textField)
    }

    private func update(stackView: NSStackView, imageView: NSImageView, textField: NSTextField) {
        imageView.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
        imageView.toolTip = title
        imageView.contentTintColor = tintColor
        textField.stringValue = title
        textField.textColor = tintColor
        stackView.toolTip = title
    }
}
