import SwiftUI

enum TaskRelationshipActionPresentation {
    static let createTaskTitle = "Create New Task"
    static let linkTaskTitle = "Link a Task"
}

struct TaskDetailGoalsHeaderBoxView: View {
    let goals: [RoutineGoalSummary]

    var body: some View {
        let tint = goals.first?.color.swiftUIColor ?? Color.accentColor

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("GOALS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(goals.count.formatted())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)
            }

            HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(goals) { goal in
                    TaskDetailGoalChip(goal: goal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct TaskDetailGoalChip: View {
    let goal: RoutineGoalSummary

    var body: some View {
        let tint = goal.color.swiftUIColor ?? Color.accentColor

        HStack(spacing: 7) {
            Text(goal.displayEmoji)
                .font(.caption.weight(.semibold))

            Text(goal.displayTitle)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .routinaGlassPill(tint: tint, tintOpacity: 0.13)
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

struct TaskDetailRelationshipsSectionView: View {
    let groups: [(kind: RoutineTaskRelationshipKind, items: [RoutineTaskResolvedRelationship])]
    let suggestions: [TaskRelationshipSuggestion]
    let hasSuggestionCandidates: Bool
    let isLoadingSuggestions: Bool
    let suggestionMessage: String?
    @Binding var selectedRelationshipKind: RoutineTaskRelationshipKind
    let showsAppleIntelligenceSuggestions: Bool
    let showsVisualizeButton: Bool
    let isVisualizeDisabled: Bool
    let background: Color
    let stroke: Color
    let onVisualize: () -> Void
    let onOpenTask: (UUID) -> Void
    let onOpenAddLinkedTask: () -> Void
    let onFindSuggestions: () -> Void
    let onChangeSuggestionKind: (UUID, RoutineTaskRelationshipKind) -> Void
    let onAcceptSuggestion: (UUID) -> Void
    let onDismissSuggestion: (UUID) -> Void
    var onLinkExistingTask: (() -> Void)? = nil

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                header

                ForEach(groups, id: \.kind) { group in
                    relationshipGroup(group)
                    Divider()
                }

                suggestionContent

                Divider()

                addRelationshipControls
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Linked Tasks")
                .font(.headline)

            Spacer(minLength: 0)

            if showsAppleIntelligenceSuggestions {
                Button {
                    onFindSuggestions()
                } label: {
                    if isLoadingSuggestions {
                        ProgressView()
                            .controlSize(.small)
                            .frame(minWidth: 20, minHeight: 20)
                    } else {
                        Label("Suggest", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoadingSuggestions || !hasSuggestionCandidates)
                .accessibilityLabel(
                    isLoadingSuggestions
                        ? "Analyzing task relationships"
                        : "Find task relationship suggestions"
                )
            }

            if showsVisualizeButton {
                Button {
                    onVisualize()
                } label: {
                    Label("Visualize", systemImage: "point.3.connected.trianglepath.dotted")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isVisualizeDisabled)
            }
        }
    }

    private func relationshipGroup(
        _ group: (kind: RoutineTaskRelationshipKind, items: [RoutineTaskResolvedRelationship])
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(group.kind.title, systemImage: group.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, relationship in
                relationshipRow(
                    relationship,
                    index: index,
                    itemCount: group.items.count
                )

                if index < group.items.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func relationshipRow(
        _ relationship: RoutineTaskResolvedRelationship,
        index: Int,
        itemCount: Int
    ) -> some View {
        Button {
            onOpenTask(relationship.taskID)
        } label: {
            HStack(spacing: 12) {
                Text(relationship.taskEmoji)
                    .font(.title3)
                    .overlay(alignment: .topLeading) {
                        if itemCount > 1 {
                            Text("\(index + 1)")
                                .fixedSize()
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .routinaGlassPill()
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .offset(x: -10, y: -8)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(relationship.taskName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if relationship.status != .onTrack {
                        Label(relationship.status.title, systemImage: relationship.status.systemImage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TaskDetailRelationshipPresentation.statusColor(for: relationship.status))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var suggestionContent: some View {
        if showsAppleIntelligenceSuggestions {
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Suggested relationships", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(suggestions) { suggestion in
                        suggestionRow(suggestion)
                    }
                }
            } else if let suggestionMessage {
                Text(suggestionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Ask Apple Intelligence to look for prerequisites and clearly related tasks. Nothing changes until you confirm.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func suggestionRow(_ suggestion: TaskRelationshipSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(suggestion.targetTaskEmoji)

                Text(suggestion.targetTaskTitle)
                    .font(.subheadline.weight(.medium))

                Spacer(minLength: 0)

                Picker("", selection: Binding(
                    get: { suggestion.kind },
                    set: { onChangeSuggestionKind(suggestion.targetTaskID, $0) }
                )) {
                    Label(
                        RoutineTaskRelationshipKind.blockedBy.title,
                        systemImage: RoutineTaskRelationshipKind.blockedBy.systemImage
                    )
                    .tag(RoutineTaskRelationshipKind.blockedBy)

                    Label(
                        RoutineTaskRelationshipKind.blocks.title,
                        systemImage: RoutineTaskRelationshipKind.blocks.systemImage
                    )
                    .tag(RoutineTaskRelationshipKind.blocks)

                    Label(
                        RoutineTaskRelationshipKind.related.title,
                        systemImage: RoutineTaskRelationshipKind.related.systemImage
                    )
                    .tag(RoutineTaskRelationshipKind.related)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            Text(suggestion.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button("Dismiss", role: .cancel) {
                    onDismissSuggestion(suggestion.targetTaskID)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("Confirm") {
                    onAcceptSuggestion(suggestion.targetTaskID)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .routinaGlassCard(
            cornerRadius: 12,
            tint: .accentColor,
            tintOpacity: 0.08,
            interactive: false
        )
    }

    private var addRelationshipControls: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedRelationshipKind) {
                ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                }
            }
            .labelsHidden()
            .fixedSize()

            if let onLinkExistingTask {
                Button {
                    onOpenAddLinkedTask()
                } label: {
                    Label(TaskRelationshipActionPresentation.createTaskTitle, systemImage: "plus.circle")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Button {
                    onLinkExistingTask()
                } label: {
                    Label(TaskRelationshipActionPresentation.linkTaskTitle, systemImage: "link")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            } else {
                Button {
                    onOpenAddLinkedTask()
                } label: {
                    Label("Add Linked Task", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}
