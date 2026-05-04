import Foundation
import PhotosUI
import SwiftUI

extension AddRoutineTCAView {
    @ViewBuilder
    var imageAttachmentContent: some View {
        AddRoutineImageAttachmentContent(
            imageData: store.basics.imageData,
            onRemove: removeImage,
            imagePreview: { TaskImageView(data: $0) },
            photoPickerButton: { label in
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(label, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            },
            importButton: { platformImageImportButton },
            dropHint: { platformImageDropHint }
        )
        .routinaAddRoutineImageImportSupport(
            isDropTargeted: $isImageDropTargeted,
            isFileImporterPresented: $isImageFileImporterPresented,
            onImport: loadPickedImage(fromFileAt:)
        )
    }

    @ViewBuilder
    var repeatPatternSections: some View {
        AddRoutineRepeatPatternSections(
            recurrenceKind: recurrenceKindBinding,
            frequency: frequencyBinding,
            frequencyValue: frequencyValueBinding,
            recurrenceTime: recurrenceTimeBinding,
            recurrenceWeekday: recurrenceWeekdayBinding,
            recurrenceDayOfMonth: recurrenceDayOfMonthBinding,
            recurrencePatternDescription: formPresentation.recurrencePatternDescription(includesOptionalExactTimeDetail: false),
            dailyTimeSummary: "Due every day at \(store.schedule.recurrenceTimeOfDay.formatted()).",
            weeklyRecurrenceSummary: formPresentation.weeklyRecurrenceSummary,
            monthlyRecurrenceSummary: formPresentation.monthlyRecurrenceSummary,
            weekdayOptions: weekdayOptions
        )
    }

    func loadPickedImage(from item: PhotosPickerItem) {
        AddRoutineImageImportSupport.loadPickedImage(
            loadData: { try? await item.loadTransferable(type: Data.self) },
            onImagePicked: { store.send(.imagePicked($0)) }
        )
    }

    func loadPickedImage(fromFileAt url: URL) {
        AddRoutineImageImportSupport.loadPickedImage(fromFileAt: url) {
            store.send(.imagePicked($0))
        }
    }

    private func removeImage() {
        selectedPhotoItem = nil
        store.send(.removeImageTapped)
    }
}
