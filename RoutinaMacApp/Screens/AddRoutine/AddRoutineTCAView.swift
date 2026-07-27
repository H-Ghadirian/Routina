import SwiftUI
import ComposableArchitecture
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
    @AppStorage(
        UserDefaultBoolValueKey.appSettingPlacesEnabled.rawValue,
        store: SharedDefaults.app
    ) var isPlacesEnabled = false
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll
    @Environment(\.addEditFormCoordinator) var formCoordinator

    var body: some View {
NavigationStack {
    addRoutineContent
    .routinaAddRoutineNavigationChrome(
        store: store,
        isSaveDisabled: isSaveDisabled,
        isSaving: store.isSaving,
        showsToolbarActions: false
    )
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
    .background {
        AddRoutineEventCatalogSyncView(
            ownerID: ObjectIdentifier(store),
            onCandidatesChanged: { candidates in
                store.send(.availableEventsChanged(candidates))
            }
        )
        .equatable()
    }
}
    }

    @ViewBuilder
    var addRoutineContent: some View {
        platformAddRoutineContent
    }

}
