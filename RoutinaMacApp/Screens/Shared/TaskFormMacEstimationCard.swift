import SwiftUI

struct TaskFormMacEstimationCard: View {
    let model: TaskFormModel

    var body: some View {
        TaskFormMacSectionCard(title: TaskFormEffortPresentation.sectionTitle) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
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
                }

                Divider()

                if model.showsActualDurationControl {
                    VStack(alignment: .leading, spacing: 10) {
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

                    Divider()
                }

                VStack(alignment: .leading, spacing: 10) {
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
                                .frame(minWidth: 160, alignment: .leading)
                        }
                        .fixedSize()
                    }
                }

                Divider()

                Toggle(isOn: model.focusModeEnabled) {
                    TaskFormEffortFieldLabel(
                        title: TaskFormEffortPresentation.focusTimerTitle,
                        detail: TaskFormEffortPresentation.focusTimerDetail
                    )
                }
                    .toggleStyle(.switch)
            }
        }
    }
}
