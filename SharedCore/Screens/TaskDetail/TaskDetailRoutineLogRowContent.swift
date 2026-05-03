import SwiftUI

struct TaskDetailRoutineLogRowContent: View {
    let timestampText: String
    let timeSpentText: String
    let statusText: String
    let statusColor: Color
    let onEditTime: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(timestampText)
                    .font(.subheadline)

                Button {
                    onEditTime()
                } label: {
                    Label(timeSpentText, systemImage: "clock")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 8)
    }
}
