import SwiftUI

struct GoalListRow: View {
    var goal: GoalsFeature.GoalDisplay

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(goal.color.swiftUIColor?.opacity(0.16) ?? Color.secondary.opacity(0.12))
                Text(goal.displayEmoji)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.displayTitle)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text("\(goal.openTaskCount) open")
                    Text("\(goal.routineCount) repeating")
                    Text("\(goal.todoCount) one-time")
                    if goal.childGoalCount > 0 {
                        Text("\(goal.childGoalCount) sub-goals")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !goal.tags.isEmpty {
                    HomeFilterFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                        ForEach(goal.tags, id: \.self) { tag in
                            RoutineTagPill(name: tag, color: nil, size: .small)
                                .fixedSize()
                        }
                    }
                }
            }

            Spacer()

            if let targetDate = goal.targetDate {
                Text(targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
