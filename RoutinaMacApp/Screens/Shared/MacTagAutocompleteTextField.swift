import AppKit
import SwiftUI

struct MacTagAutocompleteTextField: NSViewRepresentable {
    let placeholder: String
    let text: Binding<String>
    let suggestion: String?
    let onSubmit: () -> Void
    let onAcceptSuggestion: () -> Void

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacTagAutocompleteTextField

        init(parent: MacTagAutocompleteTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            if parent.text.wrappedValue != textField.stringValue {
                parent.text.wrappedValue = textField.stringValue
            }
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertTab(_:)):
                guard parent.suggestion != nil else { return false }
                parent.onAcceptSuggestion()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
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

        nsView.placeholderString = placeholder
    }
}
