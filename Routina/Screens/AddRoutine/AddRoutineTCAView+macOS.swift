#if os(macOS)
import SwiftUI

extension View {
    func routinaAddRoutineNameAutofocus(
        isRoutineNameFocused: FocusState<Bool>.Binding
    ) -> some View {
        self
    }

    func routinaAddRoutineSheetFrame() -> some View {
        frame(minWidth: 560, minHeight: 520)
    }
}
#endif
