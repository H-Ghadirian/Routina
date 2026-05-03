import SwiftUI

struct TaskFormMacGoalsContent: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            goalComposer
            goalsContent
            availableGoalSuggestionsContent
            Text(presentation.goalSectionHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var goalComposer: some View {
        HStack(spacing: 10) {
            TextField("Ship portfolio, improve health", text: model.goalDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddGoal() }

            Button("Add") { model.onAddGoal() }
                .buttonStyle(.bordered)
                .disabled(!presentation.canAddGoalDraft)
        }
    }

    @ViewBuilder
    private var goalsContent: some View {
        if model.selectedGoals.isEmpty {
            Text(model.availableGoals.isEmpty ? "No goals yet" : "No selected goals yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(model.selectedGoals) { goal in
                    Button { model.onRemoveGoal(goal.id) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "target")
                                .font(.caption)
                            Text(goal.displayTitle)
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
                    .accessibilityLabel("Remove goal \(goal.displayTitle)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var availableGoalSuggestionsContent: some View {
        if !model.availableGoals.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose from existing goals")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                HomeFilterFlowLayout(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(model.availableGoals) { goal in
                        let isSelected = model.selectedGoals.contains(where: { $0.id == goal.id })
                        Button { model.onToggleGoalSelection(goal) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(goal.displayTitle)
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
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") goal \(goal.displayTitle)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
