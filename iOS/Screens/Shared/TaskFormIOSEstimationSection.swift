import SwiftUI

struct TaskFormIOSEstimationSection: View {
    let model: TaskFormModel
    let presentation: TaskFormPresentation

    var body: some View {
        Section(header: Text("Estimation")) {
            Toggle("Set duration estimate", isOn: estimatedDurationEnabledBinding)
            if estimatedDurationEnabledBinding.wrappedValue {
                TaskFormDurationEntry(
                    title: "Estimate",
                    minutes: estimatedDurationBinding,
                    bounds: TaskFormDurationEntryPresentation.estimatedDurationBounds,
                    presets: TaskFormDurationEntryPresentation.durationPresets
                )
            }

            if model.taskType.wrappedValue == .todo, model.actualDurationMinutes != nil {
                Toggle("Set actual time spent", isOn: actualDurationEnabledBinding)
                if actualDurationEnabledBinding.wrappedValue {
                    TaskFormDurationEntry(
                        title: "Actual",
                        minutes: actualDurationBinding,
                        bounds: TaskFormDurationEntryPresentation.actualDurationBounds,
                        presets: TaskFormDurationEntryPresentation.durationPresets
                    )
                }
            }

            Toggle("Set story points", isOn: storyPointsEnabledBinding)
            if storyPointsEnabledBinding.wrappedValue {
                Stepper(value: storyPointsStepperBinding, in: 1...100) {
                    Text(TaskFormPresentation.storyPointsLabel(for: storyPointsStepperBinding.wrappedValue))
                }
            }

            Toggle("Show focus timer", isOn: model.focusModeEnabled)

            Text(presentation.estimationHelpText).font(.caption).foregroundStyle(.secondary)
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

    private var estimatedDurationBinding: Binding<Int> {
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

    private var actualDurationBinding: Binding<Int> {
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
