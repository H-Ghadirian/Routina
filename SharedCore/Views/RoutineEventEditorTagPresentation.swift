import SwiftUI

extension RoutineEventEditorView {
    var availableTags: [String] {
        RoutineTag.allTags(
            from: tasks.map(\.tags)
                + goals.map(\.tags)
                + (isNotesEnabled ? notes.map(\.tags) : [])
                + events.map(\.tags)
        )
    }

    var availableUnselectedTags: [String] {
        availableTags.filter { !RoutineTag.contains($0, in: tags) }
    }

    var tagAutocompleteSuggestion: String? {
        RoutineTag.autocompleteSuggestion(
            for: tagDraft,
            availableTags: availableTags,
            selectedTags: tags
        )
    }

    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("health, travel, work", text: $tagDraft)
                        .onSubmit(addTagDraft)
                        .padding(.trailing, tagAutocompleteSuggestion == nil ? 0 : 88)

                    if let suggestion = tagAutocompleteSuggestion {
                        Button {
                            acceptTagAutocompleteSuggestion()
                        } label: {
                            Text("#\(suggestion)")
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .routinaGlassPill(
                                    tint: .secondary,
                                    tintOpacity: 0.12,
                                    interactive: true
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Complete tag \(suggestion)")
                    }
                }

                Button {
                    addTagDraft()
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .disabled(RoutineTag.parseDraft(tagDraft).isEmpty)
            }

            selectedTagsContent
            existingTagsContent
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    var selectedTagsContent: some View {
        if tags.isEmpty {
            Text("No tags selected")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        tags = RoutineTag.removing(tag, from: tags)
                    } label: {
                        HStack(spacing: 6) {
                            Text("#\(tag)")
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .routinaGlassPill(
                            tint: .accentColor,
                            tintOpacity: 0.14,
                            interactive: true
                        )
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
    var existingTagsContent: some View {
        if !availableUnselectedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Existing tags")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(availableUnselectedTags, id: \.self) { tag in
                        Button {
                            tags = RoutineTag.appending(
                                tag,
                                to: tags,
                                availableTags: availableTags
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle")
                                    .font(.caption)
                                Text("#\(tag)")
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundStyle(.secondary)
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
                }
                .padding(.vertical, 4)
            }
        }
    }

    func addTagDraft() {
        guard !RoutineTag.parseDraft(tagDraft).isEmpty else { return }
        tags = RoutineTag.appending(tagDraft, to: tags, availableTags: availableTags)
        tagDraft = ""
    }

    func acceptTagAutocompleteSuggestion() {
        guard let suggestion = tagAutocompleteSuggestion else { return }
        tags = RoutineTag.appending(suggestion, to: tags, availableTags: availableTags)
        tagDraft = ""
    }
}
