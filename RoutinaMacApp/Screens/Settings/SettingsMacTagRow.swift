import ComposableArchitecture
import SwiftUI

private enum SettingsMacTagPalette {
    static let presets: [String] = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#32D74B",
        "#66D4CF", "#5AC8FA", "#0A84FF", "#5E5CE6",
        "#BF5AF2", "#FF375F", "#AC8E68", "#8E8E93"
    ]
}

struct SettingsMacTagRow: View {
    let store: StoreOf<SettingsFeature>
    let tag: RoutineTagSummary
    @State private var isExpanded = false
    @State private var isColorPopoverPresented = false
    @State private var relatedTagEntry = ""

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    RoutineTagPill(tag: tag)

                    if !tag.settingsSubtitle.isEmpty {
                        Text(tag.settingsSubtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    disclosureButton
                    tagActionsMenu
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                }

                if isExpanded {
                    expandedDetails
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 10)
            .contextMenu {
                Button {
                    store.send(.renameTagTapped(tag.name))
                } label: {
                    Label("Rename…", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    store.send(.deleteTagTapped(tag.name))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var disclosureButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .help(isExpanded ? "Hide details" : "Show details")
    }

    private var tagActionsMenu: some View {
        Menu {
            Button {
                store.send(.renameTagTapped(tag.name))
            } label: {
                Label("Rename…", systemImage: "pencil")
            }
            .disabled(store.tags.isTagOperationInProgress)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded = true
                }
            } label: {
                Label("Edit color & related…", systemImage: "slider.horizontal.3")
            }

            if tag.colorHex != nil {
                Button {
                    store.send(.tagColorChanged(tagName: tag.name, colorHex: nil))
                } label: {
                    Label("Reset color", systemImage: "arrow.uturn.backward")
                }
                .disabled(store.tags.isTagOperationInProgress)
            }

            Divider()

            Button(role: .destructive) {
                store.send(.deleteTagTapped(tag.name))
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(store.tags.isTagOperationInProgress)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More actions")
    }

    @ViewBuilder
    private var expandedDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            colorEditorRow

            let suggestions = store.tags.suggestedRelatedTags(for: tag.name)
            if !suggestions.isEmpty {
                relatedSuggestionSection(suggestions)
            }

            relatedTagsEditor
        }
        .padding(.leading, 4)
    }

    private var colorEditorRow: some View {
        HStack(spacing: 10) {
            Text("Color")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            colorSwatchButton

            if tag.colorHex != nil {
                Button {
                    store.send(.tagColorChanged(tagName: tag.name, colorHex: nil))
                } label: {
                    Label("Reset", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(store.tags.isTagOperationInProgress)
            }

            Spacer()
        }
    }

    private var relatedTagsEditor: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Related")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 8) {
                currentRelatedTags
                relatedTagEntryField

                Text("Related tags appear as suggestions across filters and routine forms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var currentRelatedTags: some View {
        let relatedTags = RoutineTag.parseDraft(relatedTagDraftBinding.wrappedValue)
        if relatedTags.isEmpty {
            Text("No related tags")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.vertical, 3)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(relatedTags, id: \.self) { relatedTag in
                    relatedTagChip(relatedTag)
                }
            }
        }
    }

    private var relatedTagEntryField: some View {
        HStack(spacing: 6) {
            TextField("Add related tag", text: $relatedTagEntry)
                .textFieldStyle(.roundedBorder)
                .disabled(store.tags.isTagOperationInProgress)
                .onSubmit(addRelatedTagEntry)

            Button(action: addRelatedTagEntry) {
                Label("Add", systemImage: "plus.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(
                store.tags.isTagOperationInProgress
                || RoutineTag.parseDraft(relatedTagEntry).isEmpty
            )
            .help("Add related tag")
        }
    }

    @ViewBuilder
    private func relatedSuggestionSection(_ suggestions: [String]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Suggested")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
                .padding(.top, 4)

            HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        store.send(.appendRelatedTagSuggestionTapped(
                            tagName: tag.name,
                            suggestion: suggestion
                        ))
                    } label: {
                        HStack(spacing: 4) {
                            RoutineTagPill(
                                name: suggestion,
                                color: suggestionColor(for: suggestion),
                                size: .small,
                                showsIcon: false
                            )

                            Image(systemName: "plus.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Add \(suggestion) as a related tag")
                    .disabled(store.tags.isTagOperationInProgress)
                }
            }
        }
    }

    @ViewBuilder
    private func relatedTagChip(_ relatedTag: String) -> some View {
        HStack(spacing: 4) {
            RoutineTagPill(
                name: relatedTag,
                color: suggestionColor(for: relatedTag),
                size: .small,
                showsIcon: false
            )

            Button {
                store.send(.removeRelatedTagTapped(
                    tagName: tag.name,
                    relatedTag: relatedTag
                ))
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Remove \(relatedTag)")
            .disabled(store.tags.isTagOperationInProgress)
        }
        .padding(.trailing, 2)
    }

    private func addRelatedTagEntry() {
        let submittedTags = RoutineTag.parseDraft(relatedTagEntry)
        guard !submittedTags.isEmpty else { return }
        store.send(.addRelatedTagDraftSubmitted(
            tagName: tag.name,
            draft: relatedTagEntry
        ))
        relatedTagEntry = ""
    }

    @ViewBuilder
    private var colorSwatchButton: some View {
        Button {
            isColorPopoverPresented = true
        } label: {
            Circle()
                .fill(Color(routineTagHex: tag.colorHex) ?? Color.secondary.opacity(0.4))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Change color")
        .disabled(store.tags.isTagOperationInProgress)
        .popover(isPresented: $isColorPopoverPresented, arrowEdge: .bottom) {
            colorPopoverContent
                .padding(12)
        }
    }

    @ViewBuilder
    private var colorPopoverContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pick a color")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            let columns = Array(repeating: GridItem(.fixed(28), spacing: 8), count: 4)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(SettingsMacTagPalette.presets, id: \.self) { hex in
                    let isSelected = tag.colorHex?.uppercased() == hex.uppercased()
                    Button {
                        store.send(.tagColorChanged(tagName: tag.name, colorHex: hex))
                        isColorPopoverPresented = false
                    } label: {
                        Circle()
                            .fill(Color(routineTagHex: hex) ?? .gray)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(
                                        isSelected ? Color.primary : Color.primary.opacity(0.15),
                                        lineWidth: isSelected ? 2 : 0.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(hex)
                }
            }

            Divider()

            HStack(spacing: 8) {
                ColorPicker("Custom…", selection: tagColorBinding, supportsOpacity: false)
                    .labelsHidden()

                Text("Custom…")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if tag.colorHex != nil {
                    Button("Reset") {
                        store.send(.tagColorChanged(tagName: tag.name, colorHex: nil))
                        isColorPopoverPresented = false
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }
            }
        }
        .frame(width: 200)
    }

    private func suggestionColor(for tagName: String) -> Color? {
        guard let summary = store.tags.savedTags.first(where: {
            RoutineTag.normalized($0.name) == RoutineTag.normalized(tagName)
        }) else { return nil }
        return summary.displayColor
    }

    private var tagColorBinding: Binding<Color> {
        Binding(
            get: { Color(routineTagHex: tag.colorHex) ?? .accentColor },
            set: { store.send(.tagColorChanged(tagName: tag.name, colorHex: $0.routineTagHex)) }
        )
    }

    private var relatedTagDraftBinding: Binding<String> {
        Binding(
            get: {
                guard let key = RoutineTag.normalized(tag.name) else { return "" }
                return store.tags.relatedTagDrafts[key] ?? ""
            },
            set: { store.send(.relatedTagDraftChanged(tagName: tag.name, draft: $0)) }
        )
    }
}
