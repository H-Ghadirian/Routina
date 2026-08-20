import SwiftUI

struct TaskFormMacTagsContent: View {
    let model: TaskFormModel
    let onManageTags: () -> Void

    @State private var showsAllAvailableTags = false
    @State private var showsAllAvailableFlags = false

    var body: some View {
        let tagPresentation = makeTagPresentation()
        let flagPresentation = makeFlagPresentation()
        let tagAutocompleteSuggestion = model.tagAutocompleteSuggestion

        VStack(alignment: .leading, spacing: 10) {
            tagComposer(suggestion: tagAutocompleteSuggestion)
            tagChipsContent(presentation: tagPresentation)
            flagEditor(presentation: flagPresentation)
        }
    }

    private func tagComposer(suggestion: String?) -> some View {
        HStack(spacing: 10) {
            ZStack(alignment: .trailing) {
                MacTagAutocompleteTextField(
                    placeholder: "health, focus, morning",
                    text: model.tagDraft,
                    suggestion: suggestion,
                    onSubmit: model.onAddTag,
                    onAcceptSuggestion: model.acceptTagAutocompleteSuggestion
                )
                .frame(height: 28)

                if let suggestion {
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
    private func tagChipsContent(presentation: TagPresentation) -> some View {
        if !presentation.selectedTags.isEmpty
            || !presentation.relatedTags.isEmpty
            || !presentation.availableTags.isEmpty {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(presentation.selectedTags, id: \.self) { tag in
                    selectedTagButton(tag)
                }

                ForEach(presentation.relatedTags, id: \.self) { tag in
                    relatedTagButton(tag)
                }

                ForEach(presentation.visibleAvailableTags, id: \.self) { tag in
                    availableTagButton(
                        tag,
                        summary: presentation.availableTagSummariesByNormalized[RoutineTag.normalized(tag) ?? ""]
                    )
                }

                if presentation.canToggleAvailableTags {
                    availableTagsExpansionButton(count: presentation.availableTags.count)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func flagEditor(presentation: FlagPresentation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flags")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                TextField("tracking, private", text: model.flagDraft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.onAddFlag() }

                Button { model.onAddFlag() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(RoutineFlag.parseDraft(model.flagDraft.wrappedValue).isEmpty)
                .accessibilityLabel("Add flag")
            }

            if !model.routineFlags.isEmpty {
                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(model.routineFlags, id: \.self) { flag in
                        Button { model.onRemoveFlag(flag) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "flag.fill")
                                Text(flag)
                                Image(systemName: "xmark.circle.fill").font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .routinaGlassPill(tint: .orange, tintOpacity: 0.14, interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove flag \(flag)")
                    }
                }
            }

            if let message = model.flagSelectionValidationMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !presentation.availableFlags.isEmpty {
                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(presentation.visibleAvailableFlags, id: \.self) { flag in
                        availableFlagButton(flag)
                    }

                    if presentation.canToggleAvailableFlags {
                        availableFlagsExpansionButton(count: presentation.availableFlags.count)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    private func availableFlagsExpansionButton(count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsAllAvailableFlags.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showsAllAvailableFlags ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                Text(showsAllAvailableFlags ? "Show less" : "Show all (\(count))")
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(showsAllAvailableFlags ? "Show fewer flags" : "Show all flags")
    }

    private func availableFlagButton(_ flag: String) -> some View {
        Button { model.onToggleFlagSelection(flag) } label: {
            HStack(spacing: 6) {
                Image(systemName: "flag")
                    .font(.caption)
                Text(flag)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .routinaGlassPill(tint: .orange, tintOpacity: 0.10, interactive: true)
            .overlay {
                Capsule()
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Add flag \(flag)")
    }

    private func availableTagsExpansionButton(count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showsAllAvailableTags.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: showsAllAvailableTags ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                Text(showsAllAvailableTags ? "Show less" : "Show all (\(count))")
                    .lineLimit(1)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel(showsAllAvailableTags ? "Show fewer tags" : "Show all tags")
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

    private func availableTagButton(_ tag: String, summary: RoutineTagSummary?) -> some View {
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

    private func makeTagPresentation() -> TagPresentation {
        let selectedTags = model.routineTags
        let selectedNormalized = Set(selectedTags.compactMap(RoutineTag.normalized))
        let relatedTags = model.suggestedRelatedTags.filter { tag in
            guard let normalizedTag = RoutineTag.normalized(tag) else { return false }
            return !selectedNormalized.contains(normalizedTag)
        }
        let relatedNormalized = Set(relatedTags.compactMap(RoutineTag.normalized))
        let availableTags = model.availableTags.filter { tag in
            guard let normalizedTag = RoutineTag.normalized(tag) else { return false }
            return !selectedNormalized.contains(normalizedTag)
                && !relatedNormalized.contains(normalizedTag)
        }
        let summariesByNormalized = model.availableTagSummaries.reduce(
            into: [String: RoutineTagSummary]()
        ) { summaries, summary in
            guard let normalizedName = RoutineTag.normalized(summary.name),
                  summaries[normalizedName] == nil else {
                return
            }
            summaries[normalizedName] = summary
        }

        return TagPresentation(
            selectedTags: selectedTags,
            relatedTags: relatedTags,
            availableTags: availableTags,
            visibleAvailableTags: TaskFormMacTagSuggestionPresentation.visibleAvailableTags(
                availableTags,
                showsAll: showsAllAvailableTags
            ),
            canToggleAvailableTags: availableTags.count > TaskFormMacTagSuggestionPresentation.collapsedLimit,
            availableTagSummariesByNormalized: summariesByNormalized
        )
    }

    private func makeFlagPresentation() -> FlagPresentation {
        let selectedFlags = Set(model.routineFlags.compactMap(RoutineFlag.normalized))
        let availableFlags = model.availableFlags.filter { flag in
            guard let normalizedFlag = RoutineFlag.normalized(flag) else { return false }
            return !selectedFlags.contains(normalizedFlag)
        }

        return FlagPresentation(
            availableFlags: availableFlags,
            visibleAvailableFlags: TaskFormFlagSuggestionPresentation.visibleAvailableFlags(
                availableFlags,
                showsAll: showsAllAvailableFlags
            ),
            canToggleAvailableFlags: availableFlags.count > TaskFormFlagSuggestionPresentation.collapsedLimit
        )
    }

    private func tagChipTitle(tag: String, summary: RoutineTagSummary?) -> String {
        TagCounterFormatting.chipTitle(
            tag: tag,
            summary: summary,
            mode: model.tagCounterDisplayMode
        )
    }

    private struct TagPresentation {
        let selectedTags: [String]
        let relatedTags: [String]
        let availableTags: [String]
        let visibleAvailableTags: [String]
        let canToggleAvailableTags: Bool
        let availableTagSummariesByNormalized: [String: RoutineTagSummary]
    }

    private struct FlagPresentation {
        let availableFlags: [String]
        let visibleAvailableFlags: [String]
        let canToggleAvailableFlags: Bool
    }
}

enum TaskFormMacTagSuggestionPresentation {
    static let collapsedLimit = 6

    static func visibleAvailableTags(_ tags: [String], showsAll: Bool) -> [String] {
        showsAll ? tags : Array(tags.prefix(collapsedLimit))
    }
}
