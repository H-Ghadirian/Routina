import SwiftUI

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        self
    }

    func routinaAddRoutineSheetFrame() -> some View {
        self
    }

    func routinaAddRoutineEmojiPicker<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
        }
    }

    func routinaAddRoutinePlatformLinkField() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
    }

    func routinaAddRoutineImageImportSupport(
        isDropTargeted: Binding<Bool>,
        isFileImporterPresented: Binding<Bool>,
        onImport: @escaping (URL) -> Void
    ) -> some View {
        self
    }

    func routinaTaskRelationshipSearchFieldPlatform() -> some View {
        textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}

extension AddRoutineTCAView {
    var platformAddRoutineContent: some View {
        TaskFormContent(model: makeTaskFormModel())
    }

    @ViewBuilder
    var platformImageImportButton: some View {
        EmptyView()
    }

    @ViewBuilder
    var platformImageDropHint: some View {
        EmptyView()
    }

    private func makeTaskFormModel() -> TaskFormModel {
        AddRoutineTaskFormModelFactory(
            store: store,
            emojiOptions: emojiOptions,
            isEmojiPickerPresented: $isEmojiPickerPresented
        )
        .make()
    }
}
