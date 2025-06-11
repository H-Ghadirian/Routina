import SwiftUI

struct RelationshipGraphEdge: View {
    let fromCenter: CGPoint
    let toCenter: CGPoint
    let fromSize: CGSize
    let toSize: CGSize
    let isRelated: Bool
    let color: Color

    var body: some View {
        let from = anchorPoint(center: fromCenter, toward: toCenter, size: fromSize)
        let to = anchorPoint(center: toCenter, toward: fromCenter, size: toSize)
        Path { path in
            path.move(to: from)
            let delta = max(abs(to.x - from.x) * 0.42, 40)
            let c1 = CGPoint(x: from.x + delta, y: from.y)
            let c2 = CGPoint(x: to.x - delta, y: to.y)
            path.addCurve(to: to, control1: c1, control2: c2)
        }
        .stroke(
            color,
            style: StrokeStyle(lineWidth: isRelated ? 1.5 : 2, dash: isRelated ? [6, 4] : [])
        )
    }

    private func anchorPoint(center: CGPoint, toward other: CGPoint, size: CGSize) -> CGPoint {
        let dx = other.x - center.x
        let dy = other.y - center.y
        if dx == 0, dy == 0 { return center }

        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        let tx = dx == 0 ? CGFloat.greatestFiniteMagnitude : halfWidth / abs(dx)
        let ty = dy == 0 ? CGFloat.greatestFiniteMagnitude : halfHeight / abs(dy)
        let t = min(tx, ty)

        return CGPoint(
            x: center.x + dx * t,
            y: center.y + dy * t
        )
    }
}
