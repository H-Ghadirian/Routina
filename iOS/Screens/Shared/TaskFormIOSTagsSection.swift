import SwiftUI

struct TaskFormIOSTagsSection: View {
    let model: TaskFormModel
    let tagColor: (String) -> Color?
    let onManageTags: () -> Void

    var body: some View {
        Section(header: Text("Tags")) {
            tagComposer
            tagChipsContent
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
                            .routinaGlassPill(tint: tint, tintOpacity: 0.12, interactive: true)
                            .overlay {
                                Capsule()
                                    .stroke(tint.opacity(0.28), lineWidth: 1)
                            }
                        }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.tab, modifiers: [])
                }
            }

            Button { model.onAddTag() } label: {
                Image(systemName: "plus")
            }
            .disabled(RoutineTag.parseDraft(model.tagDraft.wrappedValue).isEmpty)
            .accessibilityLabel("Add tag")

            Button(action: onManageTags) {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel("Manage Tags")
        }
    }

    @ViewBuilder
    private var tagChipsContent: some View {
        if !model.routineTags.isEmpty || !unselectedRelatedTags.isEmpty || !unselectedAvailableTags.isEmpty {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 90), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
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
        let tint = tagColor(tag) ?? .accentColor
        return Button { model.onRemoveTag(tag) } label: {
            HStack(spacing: 6) {
                Text("#\(tag)").lineLimit(1)
                Image(systemName: "xmark.circle.fill").font(.caption)
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
        .accessibilityLabel("Remove tag \(tag)")
    }

    private func relatedTagButton(_ tag: String) -> some View {
        let tint = tagColor(tag) ?? .orange
        return Button { model.onToggleTagSelection(tag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text("#\(tag)").lineLimit(1)
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
        .accessibilityLabel("Add suggested related tag \(tag)")
    }

    private func availableTagButton(_ tag: String) -> some View {
        let summary = model.availableTagSummaries.first(where: {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tag)
        })
        let tint = tagColor(tag) ?? .secondary

        return Button { model.onToggleTagSelection(tag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.caption)
                Text(tagChipTitle(tag: tag, summary: summary)).lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(
                tint: tint,
                tintOpacity: 0.10,
                interactive: true
            )
            .overlay {
                Capsule()
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add tag \(tag)")
    }

    private var unselectedAvailableTags: [String] {
        model.availableTags.filter {
            !RoutineTag.contains($0, in: model.routineTags)
                && !RoutineTag.contains($0, in: unselectedRelatedTags)
        }
    }

    private var unselectedRelatedTags: [String] {
        model.suggestedRelatedTags.filter { !RoutineTag.contains($0, in: model.routineTags) }
    }

    private func tagChipTitle(tag: String, summary: RoutineTagSummary?) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: summary,
            mode: model.tagCounterDisplayMode
        )
    }
}
