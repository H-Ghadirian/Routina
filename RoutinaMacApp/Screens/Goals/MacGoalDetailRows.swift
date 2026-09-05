import SwiftUI

struct GoalTaskSuggestionRow: View {
    var suggestion: GoalsFeature.GoalTaskSuggestionDisplay
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(suggestion.task.displayEmoji)
                .frame(width: 28, height: 28)
                .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)

            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.task.displayName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(suggestion.task.stateText)
                    if let dueDate = suggestion.task.dueDate {
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(suggestion.matchedTags, id: \.self) { tag in
                        RoutineTagPill(name: tag, color: nil, size: .small)
                            .fixedSize()
                    }
                }
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button(action: onReject) {
                    Image(systemName: "xmark")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Reject suggestion")

                Button(action: onAccept) {
                    Image(systemName: "checkmark")
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("Link task to goal")
            }
        }
        .padding(.vertical, 4)
    }
}

struct MetricLabel: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100, alignment: .leading)
    }
}

struct GoalLinkInlineRow: View {
    var goal: GoalsFeature.GoalLinkDisplay
    var relationship: String
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                    Text(goal.displayEmoji)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.displayTitle)
                    Text(relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}

struct GoalTaskInlineRow: View {
    var task: GoalsFeature.GoalTaskDisplay

    var body: some View {
        HStack(spacing: 12) {
            Text(task.displayEmoji)
                .frame(width: 28, height: 28)
                .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.displayName)
                HStack(spacing: 8) {
                    Text(task.stateText)
                    if let dueDate = task.dueDate {
                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
