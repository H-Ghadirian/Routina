import SwiftUI

struct RelationshipGraphNodeCard: View {
    let node: TaskRelationshipGraphNode
    let statusColor: (RoutineTaskRelationshipStatus) -> Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(node.emoji)
                        .font(.title3)
                    Text(node.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }

                if let kind = node.kind {
                    Label(kind.title, systemImage: kind.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let status = node.status {
                    Label(status.title, systemImage: status.systemImage)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor(status))
                } else {
                    Text("Current task")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(width: node.cardSize.width, height: node.cardSize.height, alignment: .leading)
            .background(node.isCenter ? Color.accentColor.opacity(0.14) : TaskDetailPlatformStyle.graphNodeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(node.isCenter ? Color.accentColor.opacity(0.45) : Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
