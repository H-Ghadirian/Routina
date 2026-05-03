import SwiftUI

struct AddRoutineEditableStepsView: View {
    let steps: [RoutineStep]
    let onMoveStepUp: (RoutineStep.ID) -> Void
    let onMoveStepDown: (RoutineStep.ID) -> Void
    let onRemoveStep: (RoutineStep.ID) -> Void

    var body: some View {
        if steps.isEmpty {
            Label("No steps yet", systemImage: "list.bullet")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(step.title)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Button {
                                onMoveStepUp(step.id)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button {
                                onMoveStepDown(step.id)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == steps.count - 1)

                            Button(role: .destructive) {
                                onRemoveStep(step.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}
