import SwiftUI

struct TaskDetailRoutineLogRowContent: View {
    let presentation: TaskDetailRoutineLogRowPresentation
    let timeSpentStyle: TaskDetailDurationTextStyle
    let onEditTime: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TaskDetailHistoryMarker(
                systemImage: presentation.statusSystemImage,
                tint: presentation.statusColor
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(presentation.timestampText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .layoutPriority(1)

                    TaskDetailHistoryStatusBadge(
                        title: presentation.statusText,
                        tint: presentation.statusColor
                    )
                }

                Button {
                    onEditTime()
                } label: {
                    Label(presentation.timeSpentText(style: timeSpentStyle), systemImage: "clock")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.secondary.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .contentShape(Capsule(style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }
}
