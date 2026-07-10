import SwiftUI

struct TaskDetailSectionCardView<Content: View>: View {
    let background: Color
    let stroke: Color
    let content: Content

    init(
        background: Color,
        stroke: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.background = background
        self.stroke = stroke
        self.content = content()
    }

    var body: some View {
        content
            .padding(12)
            .taskDetailScrollCardSurface(
                cornerRadius: 12,
                tint: background,
                tintOpacity: 0.18,
                stroke: stroke
            )
    }
}

extension View {
    @ViewBuilder
    func taskDetailScrollCardSurface(
        cornerRadius: CGFloat,
        tint: Color,
        tintOpacity: Double,
        stroke: Color
    ) -> some View {
        #if os(macOS)
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tint.opacity(tintOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
        #else
        routinaGlassCard(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: false
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        )
        #endif
    }
}

struct TaskDetailCollapsibleSectionHeaderView: View {
    let title: String
    let count: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.16)) {
                onToggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(count.formatted())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .routinaGlassPill(tint: .secondary, tintOpacity: 0.12)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
