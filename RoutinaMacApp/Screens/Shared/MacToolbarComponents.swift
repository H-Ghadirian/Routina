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
        let font = Self.badgeFont
        textField.font = font
        textField.textColor = tintColor
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.setContentCompressionResistancePriority(.required, for: .horizontal)
        textField.setContentHuggingPriority(.required, for: .horizontal)
        let widthConstraint = textField.widthAnchor.constraint(
            greaterThanOrEqualToConstant: Self.measuredTitleWidth(title, font: font)
        )
        widthConstraint.identifier = Self.titleWidthConstraintIdentifier
        widthConstraint.isActive = true

        let stackView = NSStackView(views: [imageView, textField])
        stackView.orientation = .horizontal
        stackView.alignment = .centerY
        stackView.spacing = 5
        stackView.edgeInsets = NSEdgeInsets(top: 0, left: 4, bottom: 0, right: 8)
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
        textField.widthConstraint?.constant = Self.measuredTitleWidth(title, font: textField.font ?? Self.badgeFont)
        textField.stringValue = title
        textField.textColor = tintColor
        stackView.toolTip = title
    }

    fileprivate static let titleWidthConstraintIdentifier = "MacToolbarStatusBadge.titleWidth"
    private static let badgeFont = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

    private static func measuredTitleWidth(_ title: String, font: NSFont) -> CGFloat {
        ceil((title as NSString).size(withAttributes: [.font: font]).width) + 2
    }
}

private extension NSTextField {
    var widthConstraint: NSLayoutConstraint? {
        constraints.first { $0.identifier == MacToolbarStatusBadge.titleWidthConstraintIdentifier }
    }
}
