#if !os(macOS)
import SwiftUI

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        onAppear {
            // Real devices can delay the first tap-to-focus inside Form.
            // Auto-focus improves perceived responsiveness.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isRoutineNameFocused.wrappedValue = true
            }
        }
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
}
#endif
