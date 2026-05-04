import SwiftUI
import UniformTypeIdentifiers

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        self
            .onAppear {
                isRoutineNameFocused.wrappedValue = false
                DispatchQueue.main.async {
                    isRoutineNameFocused.wrappedValue = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isRoutineNameFocused.wrappedValue = false
                    isRoutineNameFocused.wrappedValue = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    isRoutineNameFocused.wrappedValue = false
                    isRoutineNameFocused.wrappedValue = true
                }
            }
    }

    func routinaAddRoutineSheetFrame() -> some View {
        frame(minWidth: 620, minHeight: 430)
    }

    func routinaAddRoutineEmojiPicker<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        popover(isPresented: isPresented, arrowEdge: .top) {
            content()
                .frame(minWidth: 430, minHeight: 380)
        }
    }

    func routinaAddRoutinePlatformLinkField() -> some View {
        self
    }

    func routinaAddRoutineImageImportSupport(
        isDropTargeted: Binding<Bool>,
        isFileImporterPresented: Binding<Bool>,
        onImport: @escaping (URL) -> Void
    ) -> some View {
        background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDropTargeted.wrappedValue ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isDropTargeted.wrappedValue ? Color.accentColor : Color.secondary.opacity(0.18),
                    style: StrokeStyle(lineWidth: isDropTargeted.wrappedValue ? 2 : 1, dash: [8, 6])
                )
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let imageURL = urls.first(where: { isSupportedImageFile($0) }) else {
                return false
            }
            onImport(imageURL)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted.wrappedValue = isTargeted
        }
        .fileImporter(
            isPresented: isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result,
                  let imageURL = urls.first(where: { isSupportedImageFile($0) }) else {
                return
            }
            onImport(imageURL)
        }
    }

    func routinaTaskRelationshipSearchFieldPlatform() -> some View {
        self
    }
}

private func isSupportedImageFile(_ url: URL) -> Bool {
    guard let type = UTType(filenameExtension: url.pathExtension) else {
        return false
    }
    return type.conforms(to: .image)
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
            isEmojiPickerPresented: $isEmojiPickerPresented,
            nameFocus: $isRoutineNameFocused,
            nameFocusRequestID: formCoordinator.nameFocusRequestID
        )
        .make()
    }
}
