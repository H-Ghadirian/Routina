import Foundation
import CoreGraphics

struct TaskRelationshipGraphNode: Identifiable {
    let id: String
    let taskID: UUID
    let name: String
    let emoji: String
    let status: RoutineTaskRelationshipStatus?
    let isCenter: Bool
    let kind: RoutineTaskRelationshipKind?

    var cardSize: CGSize {
        isCenter ? CGSize(width: 220, height: 96) : CGSize(width: 190, height: 108)
    }
}

struct TaskRelationshipGraphEdgeModel: Identifiable {
    let id: String
    let fromID: String
    let toID: String
    let kind: RoutineTaskRelationshipKind
}

struct TaskRelationshipGraphLayout {
    var nodes: [TaskRelationshipGraphNode]
    var edges: [TaskRelationshipGraphEdgeModel]
    var positions: [String: CGPoint]
    var size: CGSize

    init(centerTask: RoutineTask, relationships: [RoutineTaskResolvedRelationship]) {
        let blockedBy = relationships.filter { $0.kind == .blockedBy }
        let blocks = relationships.filter { $0.kind == .blocks }
        let related = relationships.filter { $0.kind == .related }

        let centerNode = TaskRelationshipGraphNode(
            id: centerTask.id.uuidString,
            taskID: centerTask.id,
            name: centerTask.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? (centerTask.name ?? "Untitled task") : "Untitled task",
            emoji: centerTask.emoji.flatMap { $0.isEmpty ? nil : $0 } ?? "✨",
            status: nil,
            isCenter: true,
            kind: nil
        )

        let blockedNodes = blockedBy.map { relationship in
            TaskRelationshipGraphNode(
                id: relationship.id,
                taskID: relationship.taskID,
                name: relationship.taskName,
                emoji: relationship.taskEmoji,
                status: relationship.status,
                isCenter: false,
                kind: .blockedBy
            )
        }

        let blocksNodes = blocks.map { relationship in
            TaskRelationshipGraphNode(
                id: relationship.id,
                taskID: relationship.taskID,
                name: relationship.taskName,
                emoji: relationship.taskEmoji,
                status: relationship.status,
                isCenter: false,
                kind: .blocks
            )
        }

        let relatedNodes = related.map { relationship in
            TaskRelationshipGraphNode(
                id: relationship.id,
                taskID: relationship.taskID,
                name: relationship.taskName,
                emoji: relationship.taskEmoji,
                status: relationship.status,
                isCenter: false,
                kind: .related
            )
        }

        let columnSpacing: CGFloat = 280
        let rowSpacing: CGFloat = 130
        let relatedSpacing: CGFloat = 120
        let center = CGPoint(x: 600, y: 380)
        var positions: [String: CGPoint] = [:]
        positions[centerNode.id] = center

        func yOrigin(for count: Int, around middle: CGFloat, spacing: CGFloat) -> CGFloat {
            middle - (CGFloat(max(count - 1, 0)) * spacing / 2)
        }

        let blockedStartY = yOrigin(for: blockedNodes.count, around: center.y, spacing: rowSpacing)
        for (index, node) in blockedNodes.enumerated() {
            positions[node.id] = CGPoint(
                x: center.x - columnSpacing,
                y: blockedStartY + CGFloat(index) * rowSpacing
            )
        }

        let blocksStartY = yOrigin(for: blocksNodes.count, around: center.y, spacing: rowSpacing)
        for (index, node) in blocksNodes.enumerated() {
            positions[node.id] = CGPoint(
                x: center.x + columnSpacing,
                y: blocksStartY + CGFloat(index) * rowSpacing
            )
        }

        let relatedStartY = center.y + 220
        for (index, node) in relatedNodes.enumerated() {
            let direction: CGFloat = index % 2 == 0 ? -1 : 1
            let step = CGFloat((index / 2) + 1)
            positions[node.id] = CGPoint(
                x: center.x + direction * relatedSpacing * step,
                y: relatedStartY + CGFloat(index / 4) * rowSpacing
            )
        }

        var edges: [TaskRelationshipGraphEdgeModel] = []
        for node in blockedNodes {
            edges.append(
                TaskRelationshipGraphEdgeModel(
                    id: "edge-\(node.id)-center",
                    fromID: node.id,
                    toID: centerNode.id,
                    kind: .blockedBy
                )
            )
        }
        for node in blocksNodes {
            edges.append(
                TaskRelationshipGraphEdgeModel(
                    id: "edge-center-\(node.id)",
                    fromID: centerNode.id,
                    toID: node.id,
                    kind: .blocks
                )
            )
        }
        for node in relatedNodes {
            edges.append(
                TaskRelationshipGraphEdgeModel(
                    id: "edge-related-\(node.id)",
                    fromID: centerNode.id,
                    toID: node.id,
                    kind: .related
                )
            )
        }

        let allNodes = [centerNode] + blockedNodes + blocksNodes + relatedNodes
        let allPoints = allNodes.compactMap { positions[$0.id] }
        let minX = (allPoints.map(\.x).min() ?? center.x) - 220
        let maxX = (allPoints.map(\.x).max() ?? center.x) + 220
        let minY = (allPoints.map(\.y).min() ?? center.y) - 120
        let maxY = (allPoints.map(\.y).max() ?? center.y) + 140

        var normalizedPositions: [String: CGPoint] = [:]
        for (id, point) in positions {
            normalizedPositions[id] = CGPoint(x: point.x - minX, y: point.y - minY)
        }

        self.nodes = allNodes
        self.edges = edges
        self.positions = normalizedPositions
        self.size = CGSize(width: maxX - minX, height: maxY - minY)
    }
}
