import AppKit
import SwiftUI

struct MacFocusableTextField: NSViewRepresentable {
    let placeholder: String
    let text: Binding<String>
    let isFocusRequested: Bool
    let focusRequestID: Int
    var onTab: (() -> Void)?
    private let fieldFont = NSFont.systemFont(ofSize: 20)

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MacFocusableTextField
        var lastAppliedFocusRequestID: Int?
        var focusGeneration = 0
        var didFocusCurrentRequest = false

        init(parent: MacFocusableTextField) {
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
            guard commandSelector == #selector(NSResponder.insertTab(_:)),
                  let onTab = parent.onTab else {
                return false
            }
            onTab()
            return true
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
        textField.controlSize = .large
        textField.font = fieldFont
        textField.focusRingType = .default
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        nsView.controlSize = .large
        nsView.font = fieldFont

        if nsView.stringValue != text.wrappedValue {
            nsView.stringValue = text.wrappedValue
        }

        guard isFocusRequested else {
            context.coordinator.lastAppliedFocusRequestID = nil
            context.coordinator.focusGeneration += 1
            context.coordinator.didFocusCurrentRequest = false
            return
        }

        guard context.coordinator.lastAppliedFocusRequestID != focusRequestID else {
            return
        }

        context.coordinator.lastAppliedFocusRequestID = focusRequestID
        context.coordinator.focusGeneration += 1
        context.coordinator.didFocusCurrentRequest = false
        let focusGeneration = context.coordinator.focusGeneration
        let delays: [TimeInterval] = [0, 0.05, 0.15, 0.3]
        for delay in delays {
            let coordinator = context.coordinator
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak nsView] in
                guard coordinator.focusGeneration == focusGeneration,
                      let textField = nsView else {
                    return
                }
                focus(textField, coordinator: coordinator)
            }
        }
    }

    private func focus(_ textField: NSTextField, coordinator: Coordinator) {
        guard let window = textField.window else { return }
        guard shouldFocus(textField, in: window, coordinator: coordinator) else { return }
        guard window.makeFirstResponder(textField) else { return }
        coordinator.didFocusCurrentRequest = isFocused(textField, in: window)
        textField.currentEditor()?.selectedRange = NSRange(
            location: textField.stringValue.count,
            length: 0
        )
    }

    private func shouldFocus(
        _ textField: NSTextField,
        in window: NSWindow,
        coordinator: Coordinator
    ) -> Bool {
        if isFocused(textField, in: window) {
            return true
        }
        if coordinator.didFocusCurrentRequest {
            return false
        }
        if window.firstResponder is NSTextView {
            return false
        }
        return true
    }

    private func isFocused(_ textField: NSTextField, in window: NSWindow) -> Bool {
        window.firstResponder === textField || window.firstResponder === textField.currentEditor()
    }
}
