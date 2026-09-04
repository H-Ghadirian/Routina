import SwiftUI
import ComposableArchitecture

extension HomeFeature.RoutineDisplay: HomeRoutineMetadataDisplay {}

extension HomeTCAView {
    private var routineMetadataPresenter: HomeRoutineDisplayMetadataPresenter<HomeFeature.RoutineDisplay> {
        HomeRoutineDisplayMetadataPresenter(
            referenceDate: Date(),
            showPersianDates: showPersianDates,
            badgeMode: .compact,
            rowVisibility: taskRowVisibility
        )
    }

    func rowMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        routineMetadataPresenter.rowMetadataText(for: task)
    }

    func todoRowMetadataItems(for task: HomeFeature.RoutineDisplay) -> [String] {
        routineMetadataPresenter.todoRowMetadataItems(for: task)
    }

    func pressureMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        routineMetadataPresenter.pressureMetadataSuffix(for: task)
    }

    func pauseDescription(for task: HomeFeature.RoutineDisplay) -> String {
        routineMetadataPresenter.pauseDescription(for: task)
    }

    func doneCountDescription(for count: Int) -> String {
        routineMetadataPresenter.doneCountDescription(for: count)
    }

    func cadenceDescription(for task: HomeFeature.RoutineDisplay) -> String {
        routineMetadataPresenter.cadenceDescription(for: task)
    }

    func completionDescription(for task: HomeFeature.RoutineDisplay) -> String {
        routineMetadataPresenter.completionDescription(for: task)
    }

    func badgeStyle(
        for task: HomeFeature.RoutineDisplay
    ) -> HomeRoutineMetadataBadgeStyle? {
        routineMetadataPresenter.badgeStyle(for: task)
    }

    func stepMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        routineMetadataPresenter.stepMetadataSuffix(for: task)
    }

    func conciseTodoStepText(for task: HomeFeature.RoutineDisplay) -> String? {
        routineMetadataPresenter.conciseTodoStepText(for: task)
    }

    func conciseDeadlineText(for task: HomeFeature.RoutineDisplay) -> String? {
        routineMetadataPresenter.conciseDeadlineText(for: task)
    }

    func placeMetadataSuffix(for task: HomeFeature.RoutineDisplay) -> String {
        routineMetadataPresenter.placeMetadataSuffix(for: task)
    }

    func concisePlaceMetadataText(for task: HomeFeature.RoutineDisplay) -> String? {
        routineMetadataPresenter.concisePlaceMetadataText(for: task)
    }
}
