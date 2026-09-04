import AppKit
import Foundation
import SwiftUI

struct HomeMacToolbarSearchTextField: NSViewRepresentable {
    @Binding var text: String
    let isCreatingTask: Bool
    @Binding var isFocused: Bool
    let focusRequestID: Int
    let focusDismissRequestID: Int
    let onSubmit: (String) -> Void
    let onCommandSubmit: (String) -> Void

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: HomeMacToolbarSearchTextField
        weak var textField: NSTextField?
        private var shouldRestoreFocus = false
        private var focusGeneration = 0
        private var isFocusObserverInstalled = false
        private var commandReturnMonitor: Any?
        private var handledFocusRequestID: Int
        private var handledFocusDismissRequestID: Int

        init(parent: HomeMacToolbarSearchTextField) {
            self.parent = parent
            self.handledFocusRequestID = parent.focusRequestID - 1
            self.handledFocusDismissRequestID = parent.focusDismissRequestID
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func installFocusObserver() {
            guard !isFocusObserverInstalled else { return }
            isFocusObserverInstalled = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(focusSearchOrCreate),
                name: .routinaMacFocusSearchOrCreate,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(dismissSearchOrCreate),
                name: .routinaMacToolbarSearchDismissFocus,
                object: nil
            )
            installCommandReturnMonitorIfNeeded()
        }

        private func installCommandReturnMonitorIfNeeded() {
            guard commandReturnMonitor == nil else { return }
            commandReturnMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                var didConsumeEvent = false
                MainActor.assumeIsolated {
                    didConsumeEvent = self?.handleCommandReturn(event) ?? false
                }
                return didConsumeEvent ? nil : event
            }
        }

        fileprivate func removeCommandReturnMonitor() {
            if let commandReturnMonitor {
                NSEvent.removeMonitor(commandReturnMonitor)
            }
            commandReturnMonitor = nil
        }

        private func handleCommandReturn(_ event: NSEvent) -> Bool {
            guard parent.isFocused,
                !parent.isCreatingTask,
                isCommandReturnEvent(event),
                let textField,
                let window = textField.window,
                event.window === window
            else {
                return false
            }

            guard
                window.firstResponder === textField.currentEditor()
                    || window.firstResponder === textField
            else {
                return false
            }

            syncSearchText(from: textField)
            let submittedText = textField.stringValue
            dismissSearchFocus()
            parent.onCommandSubmit(submittedText)
            return true
        }

        private func isCommandReturnEvent(_ event: NSEvent) -> Bool {
            let modifierFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifierFlags.contains(.command) else { return false }
            return event.keyCode == 36 || event.keyCode == 76
        }

        @objc private func focusSearchOrCreate() {
            focusTextField(selectingText: true)
        }

        @objc private func dismissSearchOrCreate(_ notification: Notification) {
            if let targetWindow = notification.object as? NSWindow {
                if textField?.window !== targetWindow {
                    return
                }
            }
            dismissSearchFocus()
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func pointerFocusRequested() {
            parent.isFocused = true
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            syncSearchText(from: notification.object)
            guard handledFocusRequestID == parent.focusRequestID else { return }
            if let textField {
                let shouldKeepPreviewFocus =
                    HomeMacToolbarSearchInteractionBoundary
                    .currentMouseDownIsInsideParserPreview(relativeTo: textField)
                if shouldKeepPreviewFocus {
                    return
                }
            }
            parent.isFocused = false
        }

        func controlTextDidChange(_ notification: Notification) {
            syncSearchText(from: notification.object)
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                syncSearchText(from: control)
                dismissSearchFocus()
                return true
            }

            let isCommandReturn = isCommandModifiedReturn && isNewlineCommand(commandSelector)
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) || isCommandReturn else {
                return false
            }

            syncSearchText(from: control)
            guard !parent.isCreatingTask else { return true }
            let submittedText = (control as? NSTextField)?.stringValue ?? parent.text
            if isCommandReturn {
                dismissSearchFocus()
                parent.onCommandSubmit(submittedText)
                return true
            }
            parent.onSubmit(submittedText)
            restoreFocusAfterSearchUpdate()
            return true
        }

        private func isNewlineCommand(_ commandSelector: Selector) -> Bool {
            commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
        }

        private var isCommandModifiedReturn: Bool {
            guard let event = NSApp.currentEvent else { return false }
            return event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .contains(.command)
        }

        private func syncSearchText(from object: Any?) {
            guard let textField = object as? NSTextField else { return }
            let nextText = textField.stringValue
            if parent.text != nextText {
                parent.text = nextText
            }
        }

        func focusIfNeeded(for requestID: Int) {
            guard requestID != handledFocusRequestID else { return }
            guard parent.isFocused else {
                handledFocusRequestID = requestID
                return
            }
            guard focusTextField(selectingText: false) else { return }
            handledFocusRequestID = requestID
        }

        func dismissFocusIfNeeded(for requestID: Int) {
            guard requestID != handledFocusDismissRequestID else { return }
            handledFocusDismissRequestID = requestID
            dismissSearchFocus()
        }

        private func restoreFocusAfterSearchUpdate() {
            guard let textField else { return }

            let selectedRange = textField.currentEditor()?.selectedRange
            shouldRestoreFocus = true
            focusGeneration += 1
            let generation = focusGeneration
            let delays: [TimeInterval] = [0, 0.02, 0.08]
            for (index, delay) in delays.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak textField] in
                    guard let self,
                        self.shouldRestoreFocus,
                        self.focusGeneration == generation,
                        let textField,
                        let window = textField.window
                    else {
                        return
                    }

                    if self.shouldLeaveCurrentTextEditorFocused(textField, in: window) {
                        self.shouldRestoreFocus = false
                        return
                    }

                    if window.firstResponder !== textField.currentEditor() {
                        window.makeFirstResponder(textField)
                    }
                    if let editor = textField.currentEditor() {
                        let fallbackRange = NSRange(
                            location: (editor.string as NSString).length,
                            length: 0
                        )
                        editor.selectedRange = HomeMacToolbarSearchTextField.clampedSelectionRange(
                            selectedRange ?? fallbackRange,
                            in: editor.string
                        )
                    }

                    if index == delays.indices.last {
                        self.shouldRestoreFocus = false
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                guard let self, self.focusGeneration == generation else { return }
                self.shouldRestoreFocus = false
            }
        }

        private func dismissSearchFocus() {
            guard let textField else {
                parent.isFocused = false
                return
            }

            syncSearchText(from: textField)
            shouldRestoreFocus = false
            focusGeneration += 1
            let currentEditor = textField.currentEditor()
            if let window = textField.window {
                if window.firstResponder === currentEditor || window.firstResponder === textField {
                    window.makeFirstResponder(nil)
                }
            }
            parent.isFocused = false
        }

        @discardableResult
        private func focusTextField(selectingText: Bool) -> Bool {
            guard let textField,
                let window = textField.window
            else { return false }

            window.makeFirstResponder(textField)
            parent.isFocused = true
            let length = (textField.stringValue as NSString).length
            textField.currentEditor()?.selectedRange = NSRange(
                location: selectingText ? 0 : length,
                length: selectingText ? length : 0
            )
            return true
        }

        private func shouldLeaveCurrentTextEditorFocused(
            _ textField: NSTextField,
            in window: NSWindow
        ) -> Bool {
            guard let activeEditor = window.firstResponder as? NSTextView else {
                return false
            }

            return activeEditor !== textField.currentEditor()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> HomeMacToolbarSearchTextEditorView {
        let textField = HomeMacToolbarSearchClickableTextField(string: text)
        textField.onMouseDown = { [weak coordinator = context.coordinator] in
            coordinator?.pointerFocusRequested()
        }
        textField.delegate = context.coordinator
        configure(textField)
        context.coordinator.textField = textField
        context.coordinator.installFocusObserver()
        return HomeMacToolbarSearchTextEditorView(textField: textField)
    }

    func updateNSView(_ nsView: HomeMacToolbarSearchTextEditorView, context: Context) {
        let textField = nsView.textField
        context.coordinator.parent = self
        context.coordinator.textField = textField
        (textField as? HomeMacToolbarSearchClickableTextField)?.onMouseDown = { [weak coordinator = context.coordinator] in
            coordinator?.pointerFocusRequested()
        }
        let nextFocusDismissRequestID = focusDismissRequestID
        let nextFocusRequestID = focusRequestID
        DispatchQueue.main.async { [weak coordinator = context.coordinator] in
            guard let coordinator else { return }
            coordinator.dismissFocusIfNeeded(for: nextFocusDismissRequestID)
            coordinator.focusIfNeeded(for: nextFocusRequestID)
        }
        configure(textField)

        if textField.stringValue != text {
            let selectedRange = textField.currentEditor()?.selectedRange
            textField.stringValue = text
            if let editor = textField.currentEditor() {
                editor.string = text
                if let selectedRange {
                    editor.selectedRange = Self.clampedSelectionRange(selectedRange, in: text)
                }
            }
        }
    }

    @MainActor
    static func dismantleNSView(
        _ nsView: HomeMacToolbarSearchTextEditorView,
        coordinator: Coordinator
    ) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.removeCommandReturnMonitor()
    }

    private static func clampedSelectionRange(_ range: NSRange, in text: String) -> NSRange {
        let textLength = (text as NSString).length
        let location = min(max(range.location, 0), textLength)
        let length = min(max(range.length, 0), textLength - location)
        return NSRange(location: location, length: length)
    }

    private func configure(_ textField: NSTextField) {
        textField.toolTip = HomeMacToolbarSearchCopy.help
        textField.controlSize = .large
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.alignment = .left
        textField.isEditable = true
        textField.isSelectable = true
        textField.font = NSFont.systemFont(
            ofSize: NSFont.systemFontSize(for: .large),
            weight: .semibold
        )
        textField.cell?.alignment = .left
        textField.cell?.usesSingleLineMode = true
        textField.cell?.isScrollable = true
        textField.cell?.lineBreakMode = .byTruncatingTail
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

private final class HomeMacToolbarSearchClickableTextField: NSTextField {
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }
}

final class HomeMacToolbarSearchTextEditorView: NSView {
    let textField: NSTextField

    init(textField: NSTextField) {
        self.textField = textField
        super.init(frame: .zero)

        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("HomeMacToolbarSearchTextEditorView does not support decoding")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: NSView.noIntrinsicMetric,
            height: HomeMacToolbarSearchLayout.height
        )
    }

    override func layout() {
        super.layout()
        textField.needsLayout = true
        textField.layoutSubtreeIfNeeded()
    }
}
