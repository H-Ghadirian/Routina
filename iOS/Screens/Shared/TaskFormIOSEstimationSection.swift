import SwiftUI

struct TaskFormIOSEstimationSection: View {
    let model: TaskFormModel

    var body: some View {
        Section(header: Text(TaskFormEffortPresentation.sectionTitle)) {
            TaskFormEffortValueHeader(
                title: TaskFormEffortPresentation.timeEstimateTitle,
                detail: TaskFormEffortPresentation.timeEstimateDetail,
                actionTitle: TaskFormEffortPresentation.timeEstimateActionTitle(
                    minutes: model.estimatedDurationMinutes.wrappedValue
                ),
                isRemovalAction: model.hasEstimatedDuration
            ) {
                model.hasEstimatedDuration
                    ? model.clearEstimatedDuration()
                    : model.addEstimatedDuration()
            }

            if model.hasEstimatedDuration {
                TaskFormDurationEntry(
                    title: "Planned duration",
                    minutes: model.estimatedDurationValue,
                    bounds: TaskFormDurationEntryPresentation.estimatedDurationBounds,
                    presets: TaskFormDurationEntryPresentation.durationPresets
                )
            }

            if model.showsActualDurationControl {
                TaskFormEffortValueHeader(
                    title: TaskFormEffortPresentation.actualTimeTitle,
                    detail: TaskFormEffortPresentation.actualTimeDetail,
                    actionTitle: TaskFormEffortPresentation.actualTimeActionTitle(
                        minutes: model.actualDurationMinutes?.wrappedValue
                    ),
                    isRemovalAction: model.hasActualDuration
                ) {
                    model.hasActualDuration
                        ? model.clearActualDuration()
                        : model.addActualDuration()
                }

                if model.hasActualDuration {
                    TaskFormDurationEntry(
                        title: "Recorded duration",
                        minutes: model.actualDurationValue,
                        bounds: TaskFormDurationEntryPresentation.actualDurationBounds,
                        presets: TaskFormDurationEntryPresentation.durationPresets
                    )
                }
            }

            TaskFormEffortValueHeader(
                title: TaskFormEffortPresentation.storyPointsTitle,
                detail: TaskFormEffortPresentation.storyPointsDetail,
                actionTitle: TaskFormEffortPresentation.storyPointsActionTitle(
                    points: model.storyPoints.wrappedValue
                ),
                isRemovalAction: model.hasStoryPoints
            ) {
                model.hasStoryPoints
                    ? model.clearStoryPoints()
                    : model.addStoryPoints()
            }

            if model.hasStoryPoints {
                Stepper(value: model.storyPointsValue, in: 1...100) {
                    Text(TaskFormPresentation.storyPointsLabel(for: model.storyPointsValue.wrappedValue))
                }
            }

            Toggle(isOn: model.focusModeEnabled) {
                TaskFormEffortFieldLabel(
                    title: TaskFormEffortPresentation.focusTimerTitle,
                    detail: TaskFormEffortPresentation.focusTimerDetail
                )
            }
        }
    }
}
