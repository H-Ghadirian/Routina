import SwiftUI

struct RoutineLogSwipeRow: View {
    private let actionWidth: CGFloat = 76

    let presentation: TaskDetailRoutineLogRowPresentation
    let action: () -> Void
    let editTimeAction: () -> Void

    @State private var restingOffset: CGFloat = 0
    @GestureState private var dragTranslation: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if presentation.isActionEnabled {
                Button {
                    performAction()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: presentation.actionSystemImage)
                            .font(.subheadline.weight(.semibold))
                        Text(presentation.actionTitle)
                            .font(.caption2.weight(.semibold))
                    }
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(presentation.actionColor)
                .background(presentation.actionColor.opacity(0.14))
                .accessibilityHint("Performs this history correction")
            }

            rowContent
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(swipeGesture)
                .animation(.snappy(duration: 0.18), value: restingOffset)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityAction(named: presentation.actionTitle) {
            performAction()
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: presentation.statusSystemImage)
                .font(.title3)
                .foregroundStyle(presentation.statusColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(presentation.statusColor)

                Text(presentation.dateTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let supplementaryDateText = presentation.supplementaryDateText {
                    Text(supplementaryDateText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if presentation.hasTimeSpent {
                    Label(presentation.compactTimeSpentText, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            historyActionsMenu
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 9)
        .background(TaskDetailPlatformStyle.historyRowBackground)
    }

    private var historyActionsMenu: some View {
        Menu {
            Button {
                editTimeAction()
            } label: {
                Label(presentation.timeSpentActionTitle, systemImage: "clock")
            }

            if presentation.isActionEnabled {
                Divider()

                if presentation.isDestructiveAction {
                    Button(role: .destructive) {
                        performAction()
                    } label: {
                        Label(presentation.actionTitle, systemImage: presentation.actionSystemImage)
                    }
                } else {
                    Button {
                        performAction()
                    } label: {
                        Label(presentation.actionTitle, systemImage: presentation.actionSystemImage)
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("History actions")
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

                let projectedOffset = min(0, max(-actionWidth, restingOffset + predictedTranslation))
                let finalOffset = min(0, max(-actionWidth, restingOffset + translation))
                restingOffset = min(projectedOffset, finalOffset) <= -(actionWidth / 2) ? -actionWidth : 0
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
