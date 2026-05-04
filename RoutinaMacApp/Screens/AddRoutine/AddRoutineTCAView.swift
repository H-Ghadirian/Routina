import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers
import PhotosUI

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @FocusState var isRoutineNameFocused: Bool
    @State var isEmojiPickerPresented = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var isImageFileImporterPresented = false
    @State var isImageDropTargeted = false
    @State var isTagManagerPresented = false
    @State var tagManagerStore = Store(initialState: SettingsFeature.State()) {
        SettingsFeature()
    }
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll
    @Environment(\.addEditFormCoordinator) var formCoordinator

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                addRoutineContent
                .routinaAddRoutineNavigationChrome(store: store, isSaveDisabled: isSaveDisabled)
                .routinaAddRoutineNameAutofocus(isRoutineNameFocused: $isRoutineNameFocused)
                .routinaAddRoutineEmojiPicker(isPresented: $isEmojiPickerPresented) {
                    EmojiPickerSheet(
                        selectedEmoji: routineEmojiBinding,
                        emojis: allEmojiOptions
                    )
                }
                .sheet(isPresented: $isTagManagerPresented) {
                    SettingsTagManagerPresentationView(store: tagManagerStore)
                }
                .routinaAddRoutineTagNotifications(store: store)
                .routinaAddRoutineSheetFrame()
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    loadPickedImage(from: newItem)
                }
            }
        }
    }

    @ViewBuilder
    var addRoutineContent: some View {
        platformAddRoutineContent
    }

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

    private func removeImage() {
        selectedPhotoItem = nil
        store.send(.removeImageTapped)
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

    private func loadPickedImage(from item: PhotosPickerItem) {
        AddRoutineImageImportSupport.loadPickedImage(
            loadData: { try? await item.loadTransferable(type: Data.self) },
            onImagePicked: { store.send(.imagePicked($0)) }
        )
    }

    private func loadPickedImage(fromFileAt url: URL) {
        AddRoutineImageImportSupport.loadPickedImage(fromFileAt: url) {
            store.send(.imagePicked($0))
        }
    }

}
