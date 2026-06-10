import SwiftUI
import ComposableArchitecture
import PhotosUI
import SwiftData

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
    @Query(sort: \RoutineEvent.startedAt, order: .reverse) private var events: [RoutineEvent]
    let emojiOptions = EmojiCatalog.uniqueQuick
    let allEmojiOptions = EmojiCatalog.searchableAll
    @Environment(\.addEditFormCoordinator) var formCoordinator

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
    .onAppear {
        syncAvailableEvents()
    }
    .onChange(of: availableEventCandidates) { _, _ in
        syncAvailableEvents()
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

    private var availableEventCandidates: [RoutineEventLinkCandidate] {
        RoutineEventLinkCandidate.candidates(from: events)
    }

    private func syncAvailableEvents() {
        store.send(.availableEventsChanged(availableEventCandidates))
    }

}
