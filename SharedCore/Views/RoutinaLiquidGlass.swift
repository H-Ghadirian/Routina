import SwiftUI

extension View {
    @ViewBuilder
    func routinaIf<Content: View>(
        _ condition: Bool,
        transform: (Self) -> Content
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func routinaGlassCard(
        cornerRadius: CGFloat = 14,
        tint: Color? = nil,
        tintOpacity: Double = 0.16,
        interactive: Bool = false
    ) -> some View {
        routinaGlassRoundedSurface(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: interactive
        )
    }

    @ViewBuilder
    func routinaGlassPanel(
        cornerRadius: CGFloat = 18,
        tint: Color? = nil,
        tintOpacity: Double = 0.12,
        interactive: Bool = false
    ) -> some View {
        routinaGlassRoundedSurface(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: interactive
        )
    }

    @ViewBuilder
    func routinaGlassPill(
        tint: Color? = nil,
        tintOpacity: Double = 0.16,
        interactive: Bool = false
    ) -> some View {
        routinaGlassRoundedSurface(
            cornerRadius: 999,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: interactive
        )
    }

    @ViewBuilder
    private func routinaGlassRoundedSurface(
        cornerRadius: CGFloat,
        tint: Color?,
        tintOpacity: Double,
        interactive: Bool
    ) -> some View {
        if interactive {
            if let tint {
                glassEffect(
                    .regular.tint(tint.opacity(tintOpacity)).interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
            } else {
                glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            }
        } else if let tint {
            glassEffect(
                .regular.tint(tint.opacity(tintOpacity)),
                in: .rect(cornerRadius: cornerRadius)
            )
        } else {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        }
    }
}
