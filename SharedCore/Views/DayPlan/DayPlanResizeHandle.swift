import SwiftUI

#if os(macOS)
import AppKit
#endif

enum DayPlanResizeEdge {
    case top
    case bottom
}

struct DayPlanResizeHandle: View {
    var edge: DayPlanResizeEdge
    var isSelected: Bool
    var onResizeStarted: () -> Void
    var onResizeChanged: (DayPlanResizeEdge, CGFloat) -> Void
    var onResizeEnded: () -> Void

    @State private var isHovering = false
    @State private var isResizing = false

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay(alignment: .center) {
                marker
                    .opacity(isSelected || isHovering || isResizing ? 1 : 0)
            }
            .dayPlanVerticalResizeCursor()
            .onHover { isHovering = $0 }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !isResizing {
                            isResizing = true
                            onResizeStarted()
                        }
                        onResizeChanged(edge, value.translation.height)
                    }
                    .onEnded { _ in
                        isResizing = false
                        onResizeEnded()
                    }
            )
            .padding(.top, edge == .top ? -6 : 0)
            .padding(.bottom, edge == .bottom ? -6 : 0)
    }

    private var marker: some View {
        VStack(spacing: -3) {
            Image(systemName: "chevron.up")
            Capsule()
                .frame(width: 18, height: 3)
            Image(systemName: "chevron.down")
        }
        .font(.system(size: 7, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.black.opacity(0.48), in: Capsule(style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}

#if os(macOS)
private struct DayPlanVerticalResizeCursorModifier: ViewModifier {
    @State private var didPushCursor = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering, !didPushCursor {
                    NSCursor.resizeUpDown.push()
                    didPushCursor = true
                } else if !isHovering, didPushCursor {
                    NSCursor.pop()
                    didPushCursor = false
                }
            }
            .onDisappear {
                if didPushCursor {
                    NSCursor.pop()
                    didPushCursor = false
                }
            }
    }
}

private extension View {
    func dayPlanVerticalResizeCursor() -> some View {
        modifier(DayPlanVerticalResizeCursorModifier())
    }
}
#else
private extension View {
    func dayPlanVerticalResizeCursor() -> some View {
        self
    }
}
#endif
