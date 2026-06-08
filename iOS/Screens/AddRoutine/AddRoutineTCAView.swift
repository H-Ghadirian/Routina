import SwiftUI
import ComposableArchitecture
import PhotosUI

struct AddRoutineTCAView: View {
    let store: StoreOf<AddRoutineFeature>
    @Dependency(\.creationDraftClient) var creationDraftClient
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

    var body: some View {
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
    .onChange(of: AddRoutineDraftSnapshot(state: store.state)) { _, snapshot in
        snapshot.persist(client: creationDraftClient)
    }
}
    }

    @ViewBuilder
    var addRoutineContent: some View {
        platformAddRoutineContent
    }

}
