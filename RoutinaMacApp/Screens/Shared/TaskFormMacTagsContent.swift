import SwiftUI

struct TaskFormMacTagsContent: View {
    let model: TaskFormModel
    let onManageTags: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tagComposer
            tagsContent
            relatedTagSuggestionsContent
            availableTagSuggestionsContent
            manageTagsButton
        }
    }

    private var tagComposer: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                MacTagAutocompleteTextField(
                    placeholder: "health, focus, morning",
                    text: model.tagDraft,
                    suggestion: model.tagAutocompleteSuggestion,
                    onSubmit: model.onAddTag,
                    onAcceptSuggestion: model.acceptTagAutocompleteSuggestion
                )
                .frame(height: 28)

                if let suggestion = model.tagAutocompleteSuggestion {
                    Button {
                        model.acceptTagAutocompleteSuggestion()
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(suggestion)")
                            Text("Tab")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 5)
                    .help("Press Tab to complete #\(suggestion)")
                }
            }

            Button("Add") { model.onAddTag() }
                .buttonStyle(.bordered)
                .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
        }
    }

    @ViewBuilder
    private var tagsContent: some View {
        if model.routineTags.isEmpty {
            Text(model.availableTags.isEmpty ? "No tags yet" : "No selected tags yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(model.routineTags, id: \.self) { tag in
                    Button { model.onRemoveTag(tag) } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill").font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
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
        let suggestions = model.suggestedRelatedTags
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Suggested related tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.10), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.orange.opacity(0.45), lineWidth: 1)
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
        if !model.availableTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(model.availableTags, id: \.self) { tag in
                        let isSelected = RoutineTag.contains(tag, in: model.routineTags)
                        let summary = model.availableTagSummaries.first(where: {
                            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
                        })
                        Button { model.onToggleTagSelection(tag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(tagChipTitle(tag: tag, summary: summary))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? Color.accentColor.opacity(0.16)
                                        : Color.secondary.opacity(0.10)
                                )
                            )
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

    private var manageTagsButton: some View {
        Button(action: onManageTags) {
            Label("Manage Tags", systemImage: "slider.horizontal.3")
        }
        .buttonStyle(.bordered)
    }

    private func tagChipTitle(tag: String, summary: RoutineTagSummary?) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: summary,
            mode: model.tagCounterDisplayMode
        )
    }
}
