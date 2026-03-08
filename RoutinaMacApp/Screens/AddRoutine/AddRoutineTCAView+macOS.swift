#if os(macOS)
import SwiftUI

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        self
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
}
#endif
