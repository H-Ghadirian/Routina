import SwiftUI

struct RoutineLogSwipeRow: View {
    private let actionWidth: CGFloat = 88
    private let fullSwipeThreshold: CGFloat = 132

    let presentation: TaskDetailRoutineLogRowPresentation
    let action: () -> Void
    let editTimeAction: () -> Void

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if presentation.isActionEnabled {
                Button(presentation.actionTitle) {
                    performAction()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(presentation.actionColor)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.vertical, 6)
            }

            rowContent
                .background(TaskDetailPlatformStyle.summaryCardBackground)
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(swipeGesture)
                .animation(.snappy(duration: 0.18), value: restingOffset)
        }
        .clipped()
    }

    private var rowContent: some View {
        TaskDetailRoutineLogRowContent(
            presentation: presentation,
            timeSpentStyle: .compact,
            onEditTime: editTimeAction
        )
    }

    private var currentOffset: CGFloat {
        guard presentation.isActionEnabled else { return 0 }
        return min(0, max(-actionWidth, restingOffset + dragTranslation))
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragTranslation) { value, state, _ in
                guard isHorizontalSwipe(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isHorizontalSwipe(value) else { return }
                let translation = value.translation.width
                let predictedTranslation = value.predictedEndTranslation.width

                if translation <= -fullSwipeThreshold || predictedTranslation <= -fullSwipeThreshold {
                    performAction()
                } else {
                    let finalOffset = min(0, max(-actionWidth, restingOffset + translation))
                    restingOffset = finalOffset <= -(actionWidth / 2) ? -actionWidth : 0
                }
            }
    }

    private func isHorizontalSwipe(_ value: DragGesture.Value) -> Bool {
        presentation.isActionEnabled && abs(value.translation.width) > abs(value.translation.height)
    }

    private func performAction() {
        restingOffset = 0
        action()
    }
}
