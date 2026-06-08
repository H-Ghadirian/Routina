import SwiftUI

struct TaskFormMacTagsContent: View {
    let model: TaskFormModel
    let onManageTags: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            tagComposer
            tagChipsContent
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
                                .routinaGlassCard(cornerRadius: 4, tint: .secondary, tintOpacity: 0.08)
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.secondary)
                        .routinaGlassPill(interactive: true)
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

            Button { model.onAddTag() } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
            .accessibilityLabel("Add tag")
            .help("Add tag")

            Button(action: onManageTags) {
                Image(systemName: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Manage Tags")
            .help("Manage tags")
        }
    }

    @ViewBuilder
    private var tagChipsContent: some View {
        if !model.routineTags.isEmpty || !unselectedRelatedTags.isEmpty || !unselectedAvailableTags.isEmpty {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(model.routineTags, id: \.self) { tag in
                    selectedTagButton(tag)
                }

                ForEach(unselectedRelatedTags, id: \.self) { tag in
                    relatedTagButton(tag)
                }

                ForEach(unselectedAvailableTags, id: \.self) { tag in
                    availableTagButton(tag)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func selectedTagButton(_ tag: String) -> some View {
        Button { model.onRemoveTag(tag) } label: {
            HStack(spacing: 6) {
                Text("#\(tag)")
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "xmark.circle.fill").font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: .accentColor, tintOpacity: 0.14, interactive: true)
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Remove tag \(tag)")
    }

    private func relatedTagButton(_ tag: String) -> some View {
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
            .routinaGlassPill(tint: .orange, tintOpacity: 0.10, interactive: true)
            .overlay {
                Capsule()
                    .stroke(Color.orange.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Add suggested related tag \(tag)")
    }

    private func availableTagButton(_ tag: String) -> some View {
        let summary = model.availableTagSummaries.first(where: {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        })

        return Button { model.onToggleTagSelection(tag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.caption)
                Text(tagChipTitle(tag: tag, summary: summary))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(
                tint: .secondary,
                tintOpacity: 0.10,
                interactive: true
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Add tag \(tag)")
    }

    private var unselectedRelatedTags: [String] {
        model.suggestedRelatedTags.filter { !RoutineTag.contains($0, in: model.routineTags) }
    }

    private var unselectedAvailableTags: [String] {
        model.availableTags.filter {
            !RoutineTag.contains($0, in: model.routineTags)
                && !RoutineTag.contains($0, in: unselectedRelatedTags)
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
