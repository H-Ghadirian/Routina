import SwiftUI

struct TaskDetailRelationshipsSectionView: View {
    let groups: [(kind: RoutineTaskRelationshipKind, items: [RoutineTaskResolvedRelationship])]
    @Binding var selectedRelationshipKind: RoutineTaskRelationshipKind
    let isVisualizeDisabled: Bool
    let background: Color
    let stroke: Color
    let onVisualize: () -> Void
    let onOpenTask: (UUID) -> Void
    let onOpenAddLinkedTask: () -> Void

    var body: some View {
        TaskDetailSectionCardView(background: background, stroke: stroke) {
            VStack(alignment: .leading, spacing: 12) {
                header

                ForEach(groups, id: \.kind) { group in
                    relationshipGroup(group)
                    Divider()
                }

                addRelationshipControls
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Linked Tasks")
                .font(.headline)

            Spacer(minLength: 0)

            Button {
                onVisualize()
            } label: {
                Label("Visualize", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isVisualizeDisabled)
        }
    }

    private func relationshipGroup(
        _ group: (kind: RoutineTaskRelationshipKind, items: [RoutineTaskResolvedRelationship])
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(group.kind.title, systemImage: group.kind.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, relationship in
                relationshipRow(
                    relationship,
                    index: index,
                    itemCount: group.items.count
                )

                if index < group.items.count - 1 {
                    Divider()
                }
            }
        }
    }

    private func relationshipRow(
        _ relationship: RoutineTaskResolvedRelationship,
        index: Int,
        itemCount: Int
    ) -> some View {
        Button {
            onOpenTask(relationship.taskID)
        } label: {
            HStack(spacing: 12) {
                Text(relationship.taskEmoji)
                    .font(.title3)
                    .overlay(alignment: .topLeading) {
                        if itemCount > 1 {
                            Text("\(index + 1)")
                                .fixedSize()
                                .font(.caption2.monospacedDigit().weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                                .offset(x: -10, y: -8)
                        }
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(relationship.taskName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if relationship.status != .onTrack {
                        Label(relationship.status.title, systemImage: relationship.status.systemImage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TaskDetailRelationshipPresentation.statusColor(for: relationship.status))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var addRelationshipControls: some View {
        HStack(spacing: 8) {
            Picker("", selection: $selectedRelationshipKind) {
                ForEach(RoutineTaskRelationshipKind.allCases, id: \.self) { kind in
                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                }
            }
            .labelsHidden()
            .fixedSize()

            Button {
                onOpenAddLinkedTask()
            } label: {
                Label("Add Linked Task", systemImage: "plus")
                    .font(.subheadline)
            }
            .buttonStyle(.borderless)
        }
    }
}
