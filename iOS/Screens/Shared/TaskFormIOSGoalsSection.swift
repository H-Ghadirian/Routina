import SwiftUI

struct TaskFormIOSGoalsSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Goals")) {
            goalComposer
            availableGoalSuggestionsContent
            selectedGoalsContent
            Text(presentation.goalSectionHelpText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var goalComposer: some View {
        HStack(spacing: 10) {
            TextField("Ship portfolio, improve health", text: model.goalDraft)
                .onSubmit { model.onAddGoal() }
            Button("Add") { model.onAddGoal() }
                .disabled(!presentation.canAddGoalDraft)
        }
    }

    @ViewBuilder
    private var selectedGoalsContent: some View {
        if model.selectedGoals.isEmpty {
            Text(model.availableGoals.isEmpty ? "No goals yet" : "No selected goals yet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(model.selectedGoals) { goal in
                    Button { model.onRemoveGoal(goal.id) } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "target").font(.caption)
                            Text(goal.displayTitle).lineLimit(1)
                            Image(systemName: "xmark.circle.fill").font(.caption)
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.14), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
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
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(model.availableGoals) { goal in
                        let isSelected = model.selectedGoals.contains(where: { $0.id == goal.id })
                        Button { model.onToggleGoalSelection(goal) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.caption)
                                Text(goal.displayTitle).lineLimit(1)
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
                            .overlay {
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(isSelected ? "Remove" : "Add") goal \(goal.displayTitle)")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
