import SwiftUI

struct TaskFormIOSTagsSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation
    let tagColor: (String) -> Color?
    let onManageTags: () -> Void

    var body: some View {
        Section(header: Text("Tags")) {
            tagComposer
            relatedTagSuggestionsContent
            availableTagSuggestionsContent
            manageTagsButton
            selectedTagsContent
            Text(presentation.tagSectionHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var tagComposer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                TextField("health, focus, morning", text: model.tagDraft)
                    .onSubmit { model.onAddTag() }
                    .padding(.trailing, model.tagAutocompleteSuggestion == nil ? 0 : 88)

                if let suggestion = model.tagAutocompleteSuggestion {
                    Button {
                        model.acceptTagAutocompleteSuggestion()
                    } label: {
                        let tint = tagColor(suggestion) ?? .secondary
                        Text("#\(suggestion)")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .foregroundStyle(tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tint.opacity(0.12), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.28), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.tab, modifiers: [])
                }
            }

            Button("Add") { model.onAddTag() }
                .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
        }
    }

    @ViewBuilder
    private var selectedTagsContent: some View {
        if model.routineTags.isEmpty {
            Text(model.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(model.routineTags, id: \.self) { tag in
                    let tint = tagColor(tag) ?? .accentColor
                    Button { model.onRemoveTag(tag) } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)").lineLimit(1)
                            Image(systemName: "xmark.circle.fill").font(.caption)
                        }
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(tint.opacity(0.14), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(tint.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var manageTagsButton: some View {
        Button(action: onManageTags) {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
    }

    @ViewBuilder
    private var relatedTagSuggestionsContent: some View {
        let suggestions = model.suggestedRelatedTags
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested related tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(suggestions, id: \.self) { tag in
                        let tint = tagColor(tag) ?? .orange
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("#\(tag)").lineLimit(1)
                            }
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tint.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.45), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add suggested related tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var availableTagSuggestionsContent: some View {
        if !model.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: model.routineTags)
                        let summary = model.availableTagSummaries.first(where: {
                            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
                        })
                        let tint = tagColor(tag) ?? .accentColor
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(tagChipTitle(tag: tag, summary: summary)).lineLimit(1)
                            }
                            .foregroundStyle(isSelected ? tint : (tagColor(tag) ?? .secondary))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? tint.opacity(0.16)
                                        : (tagColor(tag) ?? .secondary).opacity(0.10)
                                )
                            )
                            .overlay {
                                Capsule()
                                    .stroke((tagColor(tag) ?? .secondary).opacity(0.24), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") tag \(tag)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func tagChipTitle(tag: String, summary: RoutineTagSummary?) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: summary,
            mode: model.tagCounterDisplayMode
        )
    }
}
