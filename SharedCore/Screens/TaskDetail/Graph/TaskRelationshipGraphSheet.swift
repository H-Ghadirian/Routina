import SwiftUI

struct TaskRelationshipGraphSheet: View {
    let centerTask: RoutineTask
    let relationships: [RoutineTaskResolvedRelationship]
    let statusColor: (RoutineTaskRelationshipStatus) -> Color
    let onSelectTask: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @State private var zoomAtGestureStart: CGFloat = 1
    @State private var canvasOffset: CGSize = .zero
    @State private var canvasOffsetAtDragStart: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero

    private let canvasPadding: CGFloat = 180

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    let layout = graphLayout
                    ZStack {
                        ForEach(layout.edges) { edge in
                            let from = layout.positions[edge.fromID] ?? .zero
                            let to = layout.positions[edge.toID] ?? .zero
                            let fromNode = layout.nodes.first(where: { $0.id == edge.fromID })
                            let toNode = layout.nodes.first(where: { $0.id == edge.toID })
                            RelationshipGraphEdge(
                                fromCenter: from,
                                toCenter: to,
                                fromSize: fromNode?.cardSize ?? CGSize(width: 190, height: 108),
                                toSize: toNode?.cardSize ?? CGSize(width: 190, height: 108),
                                isRelated: edge.kind == .related,
                                color: edgeColor(for: edge.kind)
                            )
                        }

                        ForEach(layout.nodes) { node in
                            RelationshipGraphNodeCard(
                                node: node,
                                statusColor: statusColor
                            ) {
                                guard !node.isCenter else { return }
                                onSelectTask(node.taskID)
                                dismiss()
                            }
                            .position(layout.positions[node.id] ?? .zero)
                        }
                    }
                    .frame(width: layout.size.width + canvasPadding * 2, height: layout.size.height + canvasPadding * 2)
                    .offset(x: canvasOffset.width + dragTranslation.width, y: canvasOffset.height + dragTranslation.height)
                    .scaleEffect(zoom)
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(TaskDetailPlatformStyle.graphSheetBackground)
                .onAppear {
                    canvasOffset = CGSize(width: proxy.size.width * 0.08, height: 0)
                    canvasOffsetAtDragStart = canvasOffset
                }
            }
            .navigationTitle("Task Relationships")
            .routinaInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset") {
                        withAnimation(.spring(duration: 0.25)) {
                            zoom = 1
                            zoomAtGestureStart = 1
                            canvasOffset = .zero
                            canvasOffsetAtDragStart = .zero
                        }
                    }
                }
            }
        }
        .routinaGraphSheetFrame()
    }

    private var graphLayout: TaskRelationshipGraphLayout {
        TaskRelationshipGraphLayout(
            centerTask: centerTask,
            relationships: relationships
        )
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onChanged { value in
                canvasOffset = CGSize(
                    width: canvasOffsetAtDragStart.width + value.translation.width,
                    height: canvasOffsetAtDragStart.height + value.translation.height
                )
            }
            .onEnded { value in
                canvasOffset = CGSize(
                    width: canvasOffsetAtDragStart.width + value.translation.width,
                    height: canvasOffsetAtDragStart.height + value.translation.height
                )
                canvasOffsetAtDragStart = canvasOffset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoom = min(max(zoomAtGestureStart * value, 0.65), 2.2)
            }
            .onEnded { _ in
                zoomAtGestureStart = zoom
            }
    }

    private func edgeColor(for kind: RoutineTaskRelationshipKind) -> Color {
        switch kind {
        case .blockedBy:
            return .orange.opacity(0.85)
        case .blocks:
            return .blue.opacity(0.85)
        case .related:
            return .secondary.opacity(0.6)
        }
    }
}
