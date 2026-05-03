import SwiftUI

struct TaskDetailRoutineLogRowContent: View {
    let presentation: TaskDetailRoutineLogRowPresentation
    let timeSpentStyle: TaskDetailDurationTextStyle
    let onEditTime: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.timestampText)
                    .font(.subheadline)

                Button {
                    onEditTime()
                } label: {
                    Label(presentation.timeSpentText(style: timeSpentStyle), systemImage: "clock")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(presentation.statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(presentation.statusColor)
        }
        .padding(.vertical, 8)
    }
}
