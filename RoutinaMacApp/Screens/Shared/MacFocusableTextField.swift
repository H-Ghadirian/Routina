import AppKit
import SwiftUI

struct MacFocusableTextField: NSViewRepresentable {
    let placeholder: String
    let text: Binding<String>
    let isFocusRequested: Bool
    let focusRequestID: Int

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacFocusableTextField
        var lastAppliedFocusRequestID: Int?

        init(parent: MacFocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            if parent.text.wrappedValue != textField.stringValue {
                parent.text.wrappedValue = textField.stringValue
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text.wrappedValue)
        textField.placeholderString = placeholder
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .default
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self

        if nsView.stringValue != text.wrappedValue {
            nsView.stringValue = text.wrappedValue
        }

        guard isFocusRequested else {
            context.coordinator.lastAppliedFocusRequestID = nil
            return
        }

        guard context.coordinator.lastAppliedFocusRequestID != focusRequestID else {
            return
        }

        context.coordinator.lastAppliedFocusRequestID = focusRequestID
        let delays: [TimeInterval] = [0, 0.05, 0.15, 0.3, 0.6, 1.0, 1.5]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                focus(nsView)
            }
        }
    }

    private func focus(_ textField: NSTextField) {
        guard let window = textField.window else { return }
        window.makeFirstResponder(textField)
        textField.currentEditor()?.selectedRange = NSRange(location: textField.stringValue.count, length: 0)
    }
}
