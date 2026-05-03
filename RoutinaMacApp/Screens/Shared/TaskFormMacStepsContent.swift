import SwiftUI

struct TaskFormMacStepsContent: View {
    let model: TaskFormModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepComposer
            stepsContent
        }
    }

    private var stepComposer: some View {
        HStack(spacing: 10) {
            TextField("Wash clothes", text: model.stepDraft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { model.onAddStep() }

            Button("Add") { model.onAddStep() }
                .buttonStyle(.bordered)
                .disabled(RoutineStep.normalizedTitle(model.stepDraft.wrappedValue) == nil)
        }
    }

    @ViewBuilder
    private var stepsContent: some View {
        if model.routineSteps.isEmpty {
            Text("No steps yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(model.routineSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Text("\(index + 1).")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .leading)

                        Text(step.title)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 6) {
                            Button { model.onMoveStepUp(step.id) } label: {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)

                            Button { model.onMoveStepDown(step.id) } label: {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == model.routineSteps.count - 1)

                            Button(role: .destructive) { model.onRemoveStep(step.id) } label: {
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
