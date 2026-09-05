import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

extension TaskFormContent {
    var presentation: TaskFormPresentation {
        TaskFormPresentation(
            taskType: model.taskType.wrappedValue,
            scheduleMode: model.scheduleMode.wrappedValue,
            recurrenceKind: model.recurrenceKind.wrappedValue,
            recurrenceHasExplicitTime: model.recurrenceHasExplicitTime.wrappedValue,
            recurrenceHasTimeRange: model.recurrenceHasTimeRange.wrappedValue,
            recurrenceWeekday: model.recurrenceWeekday.wrappedValue,
            recurrenceDayOfMonth: model.recurrenceDayOfMonth.wrappedValue,
            recurrenceWeekdays: model.effectiveRecurrenceWeekdays,
            recurrenceDaysOfMonth: model.effectiveRecurrenceDaysOfMonth,
            importance: model.importance.wrappedValue,
            urgency: model.urgency.wrappedValue,
            hasAvailableTags: !model.availableTags.isEmpty,
            hasAvailableGoals: !model.availableGoals.isEmpty,
            goalDraft: model.goalDraft.wrappedValue,
            selectedPlaceName: isPlacesEnabled ? selectedPlaceName : nil,
            canAutoAssumeDailyDone: model.canAutoAssumeDailyDone
        )
    }

    private var selectedPlaceName: String? {
        if let id = model.selectedPlaceIDsValue.first,
            let place = model.availablePlaces.first(where: { $0.id == id })
        {
            return place.name
        }
        return nil
    }

    // MARK: - Live preview helpers

    private var previewTitle: String {
        let trimmed = model.name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let taskTypeTitle = model.taskType.wrappedValue.userFacingTitle.lowercased()
        return trimmed.isEmpty
            ? "New \(taskTypeTitle)"
            : trimmed
    }

    private var previewSubtitle: String {
        switch model.taskType.wrappedValue {
        case .todo:
            return model.deadlineEnabled.wrappedValue
                ? "A one-off task with a deadline."
                : "A one-off task you can finish once."
        case .routine:
            break
        }
        switch model.scheduleMode.wrappedValue {
        case .fixedInterval: return "A repeating task with one shared cadence."
        case .softInterval: return "A gentle repeating task that stays visible and resurfaces without overdue pressure."
        case .fixedIntervalChecklist: return "A repeating task you complete by finishing every checklist item."
        case .softIntervalChecklist: return "A gentle repeating task you complete by finishing every checklist item."
        case .derivedFromChecklist: return "A repeating task driven by the due dates of its checklist items."
        case .softDerivedFromChecklist: return "A gentle repeating task driven by checklist item timing."
        case .oneOff: return "A one-off task you can finish once."
        }
    }

    private var previewScheduleSummary: String {
        switch model.taskType.wrappedValue {
        case .todo:
            return model.deadlineEnabled.wrappedValue
                ? "Due \(deadlineSummaryText)"
                : "One-off"
        case .routine:
            break
        }
        switch model.recurrenceKind.wrappedValue {
        case .intervalDays:
            return TaskFormPresentation.stepperLabel(
                unit: model.frequencyUnit.wrappedValue,
                value: model.frequencyValue.wrappedValue
            )
        case .dailyTime:
            if model.recurrenceHasTimeRange.wrappedValue {
                return "Daily \(previewTimeRangeText)"
            }
            return "Daily at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
        case .weekly:
            let weekdayText = TaskFormPresentation.weekdayListText(for: model.effectiveRecurrenceWeekdays)
            if model.recurrenceHasTimeRange.wrappedValue {
                return "Every \(weekdayText) \(previewTimeRangeText)"
            }
            if model.recurrenceHasExplicitTime.wrappedValue {
                return "Every \(weekdayText) at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
            }
            return "Every \(weekdayText)"
        case .monthlyDay:
            if model.recurrenceHasTimeRange.wrappedValue {
                return TaskFormPresentation.monthlyScheduleSummary(
                    for: model.effectiveRecurrenceDaysOfMonth,
                    timingText: previewTimeRangeText
                )
            }
            if model.recurrenceHasExplicitTime.wrappedValue {
                return TaskFormPresentation.monthlyScheduleSummary(
                    for: model.effectiveRecurrenceDaysOfMonth,
                    timingText: "at \(model.recurrenceTimeOfDay.wrappedValue.formatted(date: .omitted, time: .shortened))"
                )
            }
            return TaskFormPresentation.monthlyScheduleSummary(for: model.effectiveRecurrenceDaysOfMonth)
        }
    }

    private var deadlineSummaryText: String {
        PersianDateDisplay.appendingSupplementaryDate(
            to: model.deadline.wrappedValue.formatted(date: .abbreviated, time: .omitted),
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    private var previewTimeRangeText: String {
        "\(model.recurrenceTimeRangeStart.wrappedValue.formatted(date: .omitted, time: .shortened))-\(model.recurrenceTimeRangeEnd.wrappedValue.formatted(date: .omitted, time: .shortened))"
    }

    var persianDeadlineText: String? {
        PersianDateDisplay.supplementaryText(
            for: model.deadline.wrappedValue,
            enabled: showPersianDates
        )
    }

    // MARK: - Utilities

    func isSupportedImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    func loadPickedImage(from item: PhotosPickerItem) {
        _ = Task {
            let data = try? await item.loadTransferable(type: Data.self)
            _ = await MainActor.run {
                model.onImagePicked(data)
            }
        }
    }

    func loadPickedImage(fromFileAt url: URL) {
        let compressedData = TaskImageProcessor.compressedImageData(fromFileAt: url)
        model.onImagePicked(compressedData)
    }

    func browseForImageFile() {
        Task { @MainActor in
            guard let url = await PlatformSupport.selectTaskImageURL(),
                isSupportedImageFile(url)
            else {
                return
            }
            loadPickedImage(fromFileAt: url)
        }
    }

    func loadAttachment(fromFileAt url: URL) {
        let maxSize = 20 * 1024 * 1024  // 20 MB
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let data = try? Data(contentsOf: url), data.count <= maxSize else { return }
        model.onAttachmentPicked(data, url.lastPathComponent)
    }
}
