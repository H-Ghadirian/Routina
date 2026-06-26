import ComposableArchitecture
import SwiftUI
#if os(macOS)
import AppKit
#endif

struct GoalsEditorToolbarContent: ToolbarContent {
    let store: StoreOf<GoalsFeature>

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                store.send(.dismissEditor)
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                store.send(.saveEditorTapped)
            }
            .disabled(store.editorDraft.cleanedTitle == nil)
        }
    }
}

struct GoalsEditorForm: View {
    let store: StoreOf<GoalsFeature>
    @AppStorage(
        UserDefaultBoolValueKey.appSettingNotesEnabled.rawValue,
        store: SharedDefaults.app
    ) private var isNotesEnabled = false

    var body: some View {
        Form {
            Section {
                TextField("Title", text: titleBinding)

                TextField("Emoji", text: emojiBinding)

                if isNotesEnabled {
                    TextField("Notes", text: notesBinding, axis: .vertical)
                        .lineLimit(3...6)
                }
            }

            Section {
                Toggle("Target Date", isOn: targetDateEnabledBinding)

                if let targetDate = store.editorDraft.targetDate {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { targetDate },
                            set: { store.send(.editorTargetDateChanged($0)) }
                        ),
                        displayedComponents: .date
                    )
                }
            }

            Section("Tags") {
                tagComposer
                relatedTagSuggestionsContent
                availableTagSuggestionsContent
                selectedTagsContent
            }

            Section {
                Picker("Color", selection: colorBinding) {
                    ForEach(RoutineTaskColor.allCases, id: \.self) { color in
                        HStack {
                            GoalColorSwatch(color: color)
                            Text(color.displayName)
                        }
                        .tag(color)
                    }
                }
            }

            if !store.availableParentGoals.isEmpty || store.editorDraft.parentGoalID != nil {
                Section {
                    Picker("Parent Goal", selection: parentGoalBinding) {
                        Text("No Parent").tag(Optional<UUID>.none)
                        ForEach(store.availableParentGoals) { goal in
                            Text(goal.displayTitle).tag(Optional(goal.id))
                        }
                    }

                    Text("Sub-goals appear on the parent goal detail.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let validationMessage = store.validationMessage {
                Section {
                    Text(validationMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.title },
            set: { store.send(.editorTitleChanged($0)) }
        )
    }

    private var emojiBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.emoji },
            set: { store.send(.editorEmojiChanged($0)) }
        )
    }

    private var notesBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.notes },
            set: { store.send(.editorNotesChanged($0)) }
        )
    }

    private var targetDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { store.editorDraft.hasTargetDate },
            set: { store.send(.editorTargetDateEnabledChanged($0)) }
        )
    }

    private var tagDraftBinding: Binding<String> {
        Binding(
            get: { store.editorDraft.tagDraft },
            set: { store.send(.editorTagDraftChanged($0)) }
        )
    }

    private var tagComposer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                #if os(macOS)
                GoalTagAutocompleteTextField(
                    placeholder: "health, focus, morning",
                    text: tagDraftBinding,
                    suggestion: tagAutocompleteSuggestion,
                    onSubmit: { store.send(.editorAddTagTapped) },
                    onAcceptSuggestion: { store.send(.editorAcceptTagAutocompleteTapped) }
                )
                .frame(height: 28)
                #else
                TextField("health, focus, morning", text: tagDraftBinding)
                    .onSubmit {
                        store.send(.editorAddTagTapped)
                    }
                    .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 88)
                #endif

                if let suggestion = tagAutocompleteSuggestion {
                    Button {
                        store.send(.editorAcceptTagAutocompleteTapped)
                    } label: {
                        let tint = tagColor(for: suggestion) ?? .secondary
                        HStack(spacing: 6) {
                            Text("#\(suggestion)")
                                .lineLimit(1)
                            #if os(macOS)
                            Text("Tab")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .routinaGlassCard(cornerRadius: 4, tint: .secondary, tintOpacity: 0.08)
                            #endif
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .routinaGlassPill(tint: tint, tintOpacity: 0.12, interactive: true)
                        .overlay {
                            Capsule()
                                .stroke(tint.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.tab, modifiers: [])
                    #if os(macOS)
                    .padding(.trailing, 5)
                    .help("Press Tab to complete #\(suggestion)")
                    #endif
                }
            }

            Button("Add") {
                store.send(.editorAddTagTapped)
            }
            .disabled(RoutineTag.parseDraft(store.editorDraft.tagDraft).isEmpty)
        }
    }

    @ViewBuilder
    private var selectedTagsContent: some View {
        if store.editorDraft.tags.isEmpty {
            Text(store.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(store.editorDraft.tags, id: \.self) { tag in
                    let tint = tagColor(for: tag) ?? .accentColor
                    Button {
                        store.send(.editorRemoveTagTapped(tag))
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(tint: tint, tintOpacity: 0.14, interactive: true)
                        .overlay {
                            Capsule()
                                .stroke(tint.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                    .accessibilityLabel("Remove tag \(tag)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var relatedTagSuggestionsContent: some View {
        if !suggestedRelatedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested related tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(suggestedRelatedTags, id: \.self) { tag in
                        let tint = tagColor(for: tag) ?? .orange
                        Button {
                            store.send(.editorToggleTagSelection(tag))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .routinaGlassPill(tint: tint, tintOpacity: 0.10, interactive: true)
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityLabel("Add suggested related tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var availableTagSuggestionsContent: some View {
        if !store.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(store.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: store.editorDraft.tags)
                        let tint = tagColor(for: tag) ?? .accentColor
                        Button {
                            store.send(.editorToggleTagSelection(tag))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(tagChipTitle(for: tag))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(isSelected ? tint : (tagColor(for: tag) ?? .secondary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .routinaGlassPill(
                                tint: isSelected ? tint : (tagColor(for: tag) ?? .secondary),
                                tintOpacity: isSelected ? 0.16 : 0.10,
                                interactive: true
                            )
                            .overlay {
                                Capsule()
                                    .stroke((tagColor(for: tag) ?? .secondary).opacity(0.24), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var tagAutocompleteSuggestion: String? {
        RoutineTag.autocompleteSuggestion(
            for: store.editorDraft.tagDraft,
            availableTags: store.availableTags,
            selectedTags: store.editorDraft.tags
        )
    }

    private var suggestedRelatedTags: [String] {
        RoutineTagRelations.relatedTags(
            for: store.editorDraft.tags,
            rules: store.relatedTagRules,
            availableTags: store.availableTags
        )
    }

    private func tagChipTitle(for tag: String) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: tagSummary(for: tag),
            mode: store.tagCounterDisplayMode
        )
    }

    private func tagColor(for tag: String) -> Color? {
        tagSummary(for: tag)?.displayColor
            ?? Color(routineTagHex: RoutineTagColors.colorHex(for: tag, in: store.tagColors))
    }

    private func tagSummary(for tag: String) -> RoutineTagSummary? {
        store.availableTagSummaries.first {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        }
    }

    private var colorBinding: Binding<RoutineTaskColor> {
        Binding(
            get: { store.editorDraft.color },
            set: { store.send(.editorColorChanged($0)) }
        )
    }

    private var parentGoalBinding: Binding<UUID?> {
        Binding(
            get: { store.editorDraft.parentGoalID },
            set: { store.send(.editorParentGoalChanged($0)) }
        )
    }
}

struct GoalColorSwatch: View {
    var color: RoutineTaskColor

    var body: some View {
        Circle()
            .fill(color.swiftUIColor ?? Color.secondary.opacity(0.25))
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.25), lineWidth: color == .none ? 1 : 0)
            }
            .accessibilityHidden(true)
    }
}

#if os(macOS)
private struct GoalTagAutocompleteTextField: NSViewRepresentable {
    let placeholder: String
    let text: Binding<String>
    let suggestion: String?
    let onSubmit: () -> Void
    let onAcceptSuggestion: () -> Void

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: GoalTagAutocompleteTextField

        init(parent: GoalTagAutocompleteTextField) {
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
#endif
