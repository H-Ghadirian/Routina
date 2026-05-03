import SwiftUI

struct TaskFormMacEstimationCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: "Estimation") {
            VStack(alignment: .leading, spacing: 18) {
                TaskFormMacControlBlock(
                    title: "Duration",
                    caption: model.taskType.wrappedValue == .todo
                        ? "Estimate is the plan. Actual time records what really happened."
                        : "Estimate is the plan. Routines record actual time on each completion."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set duration estimate", isOn: estimatedDurationEnabledBinding)
                        if estimatedDurationEnabledBinding.wrappedValue {
                            Stepper(value: estimatedDurationStepperBinding, in: 5...10_080, step: 5) {
                                Text(TaskFormPresentation.estimatedDurationLabel(for: estimatedDurationStepperBinding.wrappedValue))
                                    .frame(minWidth: 160, alignment: .leading)
                            }
                            .fixedSize()
                        }
                        if model.taskType.wrappedValue == .todo, model.actualDurationMinutes != nil {
                            Toggle("Set actual time spent", isOn: actualDurationEnabledBinding)
                            if actualDurationEnabledBinding.wrappedValue {
                                Stepper(value: actualDurationStepperBinding, in: 1...1_440, step: 5) {
                                    Text(TaskFormPresentation.estimatedDurationLabel(for: actualDurationStepperBinding.wrappedValue))
                                        .frame(minWidth: 160, alignment: .leading)
                                }
                                .fixedSize()
                            }
                        }
                    }
                }

                TaskFormMacControlBlock(title: "Story points") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Set story points", isOn: storyPointsEnabledBinding)
                        if storyPointsEnabledBinding.wrappedValue {
                            Stepper(value: storyPointsStepperBinding, in: 1...100) {
                                Text(TaskFormPresentation.storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
                                    .frame(minWidth: 160, alignment: .leading)
                            }
                            .fixedSize()
                        }
                    }
                }

                TaskFormMacControlBlock(title: "Focus") {
                    Toggle("Show focus timer", isOn: model.focusModeEnabled)
                }
            }
        }
    }

    private var estimatedDurationEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.estimatedDurationMinutes.wrappedValue != nil },
            set: { isEnabled in
                model.estimatedDurationMinutes.wrappedValue = isEnabled
                    ? (model.estimatedDurationMinutes.wrappedValue ?? 30)
                    : nil
            }
        )
    }

    private var estimatedDurationStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.estimatedDurationMinutes.wrappedValue ?? 30, 5) },
            set: { model.estimatedDurationMinutes.wrappedValue = RoutineTask.sanitizedEstimatedDurationMinutes(max($0, 5)) }
        )
    }

    private var actualDurationEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.actualDurationMinutes?.wrappedValue != nil },
            set: { isEnabled in
                guard let actualDurationMinutes = model.actualDurationMinutes else { return }
                actualDurationMinutes.wrappedValue = isEnabled
                    ? (actualDurationMinutes.wrappedValue ?? model.estimatedDurationMinutes.wrappedValue ?? 30)
                    : nil
            }
        )
    }

    private var actualDurationStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.actualDurationMinutes?.wrappedValue ?? model.estimatedDurationMinutes.wrappedValue ?? 30, 1) },
            set: { model.actualDurationMinutes?.wrappedValue = RoutineTask.sanitizedActualDurationMinutes(max($0, 1)) }
        )
    }

    private var storyPointsEnabledBinding: Binding<Bool> {
        Binding(
            get: { model.storyPoints.wrappedValue != nil },
            set: { isEnabled in
                model.storyPoints.wrappedValue = isEnabled
                    ? (model.storyPoints.wrappedValue ?? 1)
                    : nil
            }
        )
    }

    private var storyPointsStepperBinding: Binding<Int> {
        Binding(
            get: { max(model.storyPoints.wrappedValue ?? 1, 1) },
            set: { model.storyPoints.wrappedValue = RoutineTask.sanitizedStoryPoints(max($0, 1)) }
        )
    }
}
