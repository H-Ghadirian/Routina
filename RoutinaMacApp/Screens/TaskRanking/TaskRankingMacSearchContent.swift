import SwiftUI

struct TaskRankingMacSearchResults: View {
    let searchPresentation: TaskRankingSearchPresentation
    let searchText: String
    let onSelectMatch: (UUID) -> Void
    let onOpenOutsideMatch: (UUID) -> Void

    @ViewBuilder
    var body: some View {
        if searchPresentation.matches.isEmpty
            && searchPresentation.outsideMatches.isEmpty
        {
            ContentUnavailableView.search(text: searchText)
                .padding(.vertical, 18)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                if !searchPresentation.matches.isEmpty {
                    searchResultHeader(
                        title: "Found in Task Ladder",
                        count: searchPresentation.matches.count
                    )

                    ForEach(searchPresentation.matches) { match in
                        Button {
                            onSelectMatch(match.task.id)
                        } label: {
                            HStack(spacing: 9) {
                                Text(match.task.emoji ?? "✨")

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(match.task.name ?? "Untitled task")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(2)

                                    Text(match.locationTitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 4)

                                Text("Locate")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                    }
                }

                if !searchPresentation.outsideMatches.isEmpty {
                    searchResultHeader(
                        title: "Outside Task Ladder",
                        count: searchPresentation.outsideMatches.count
                    )
                    .padding(.top, searchPresentation.matches.isEmpty ? 0 : 6)

                    ForEach(searchPresentation.outsideMatches) { match in
                        Button {
                            onOpenOutsideMatch(match.task.id)
                        } label: {
                            HStack(spacing: 9) {
                                Text(match.task.emoji ?? "✨")

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(match.task.name ?? "Untitled task")
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(2)

                                    Text(match.reason)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 4)

                                Text("Open")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    private func searchResultHeader(title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

struct TaskRankingMacLinkedTaskSuggestions: View {
    let presentation: TaskRankingPresentation
    let onReject: (UUID, UUID) -> Void
    let onAccept: (UUID, UUID) -> Void

    var body: some View {
        linkedTaskChildSuggestionsHeader(
            count: presentation.linkedTaskChildSuggestions.count
        )

        ForEach(presentation.linkedTaskChildSuggestions) { suggestion in
            VStack(spacing: 0) {
                linkedTaskChildSuggestionRow(suggestion)

                if suggestion.id != presentation.linkedTaskChildSuggestions.last?.id {
                    Divider().padding(.leading, 12)
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.62))
        }
    }

    private func linkedTaskChildSuggestionsHeader(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Linked task suggestions", systemImage: "link.badge.plus")
                    .font(.headline)

                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }

            // swiftlint:disable line_length
            Text(
                "Accept a linked task to place it in this group. Rejecting only hides the suggestion; either choice keeps the task link and its completion behavior unchanged."
            )
            // swiftlint:enable line_length
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.09))
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func linkedTaskChildSuggestionRow(
        _ suggestion: TaskRankingPresentation.LinkedTaskChildSuggestion
    ) -> some View {
        HStack(spacing: 10) {
            Text(suggestion.taskEmoji)
                .font(.body)

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.taskName)
                    .font(.subheadline)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Label(
                        suggestion.relationshipKind.title,
                        systemImage: suggestion.relationshipKind.systemImage
                    )

                    if suggestion.willMoveFromAnotherPlacement {
                        Text("Moves from its current Ladder location")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            Button {
                onReject(suggestion.parentTaskID, suggestion.taskID)
            } label: {
                Label("Reject", systemImage: "xmark")
            }
            .buttonStyle(.bordered)
            .help("Hide this child suggestion without removing the task link")

            Button {
                onAccept(suggestion.parentTaskID, suggestion.taskID)
            } label: {
                Label("Accept", systemImage: "checkmark")
            }
            .buttonStyle(.borderedProminent)
            .help("Place this linked task inside the group")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
