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
        interactive: Bool = false,
        fallback: Material = .regularMaterial
    ) -> some View {
        routinaGlassRoundedSurface(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: interactive,
            fallback: fallback
        )
    }

    @ViewBuilder
    func routinaGlassPanel(
        cornerRadius: CGFloat = 18,
        tint: Color? = nil,
        tintOpacity: Double = 0.12,
        interactive: Bool = false,
        fallback: Material = .regularMaterial
    ) -> some View {
        routinaGlassRoundedSurface(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: interactive,
            fallback: fallback
        )
    }

    @ViewBuilder
    func routinaGlassPill(
        tint: Color? = nil,
        tintOpacity: Double = 0.16,
        interactive: Bool = false,
        fallback: Material = .regularMaterial
    ) -> some View {
        routinaGlassRoundedSurface(
            cornerRadius: 999,
            tint: tint,
            tintOpacity: tintOpacity,
            interactive: interactive,
            fallback: fallback
        )
    }

    @ViewBuilder
    private func routinaGlassRoundedSurface(
        cornerRadius: CGFloat,
        tint: Color?,
        tintOpacity: Double,
        interactive: Bool,
        fallback: Material
    ) -> some View {
        #if os(iOS) || os(macOS)
        if #available(iOS 26.0, macOS 26.0, *) {
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
        } else {
            routinaLegacyRoundedSurface(
                cornerRadius: cornerRadius,
                tint: tint,
                tintOpacity: tintOpacity,
                fallback: fallback
            )
        }
        #else
        routinaLegacyRoundedSurface(
            cornerRadius: cornerRadius,
            tint: tint,
            tintOpacity: tintOpacity,
            fallback: fallback
        )
        #endif
    }

    @ViewBuilder
    private func routinaLegacyRoundedSurface(
        cornerRadius: CGFloat,
        tint: Color?,
        tintOpacity: Double,
        fallback: Material
    ) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fallback)

            if let tint {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint.opacity(tintOpacity))
            }
        }
    }
}
