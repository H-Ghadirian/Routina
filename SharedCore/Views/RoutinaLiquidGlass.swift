import SwiftUI

struct RoutinaGlassSegmentedControl<Option: Hashable, Label: View>: View {
    let accessibilityLabel: String
    let options: [Option]
    @Binding var selection: Option
    let minimumSegmentWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let fillsAvailableWidth: Bool
    let tint: (Option) -> Color
    @ViewBuilder let label: (Option) -> Label
    @Namespace private var glassNamespace

    init(
        accessibilityLabel: String,
        options: [Option],
        selection: Binding<Option>,
        minimumSegmentWidth: CGFloat = 68,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 7,
        fillsAvailableWidth: Bool = false,
        tint: @escaping (Option) -> Color = { _ in .accentColor },
        @ViewBuilder label: @escaping (Option) -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        self._selection = selection
        self.minimumSegmentWidth = minimumSegmentWidth
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.fillsAvailableWidth = fillsAvailableWidth
        self.tint = tint
        self.label = label
    }

    var body: some View {
        if fillsAvailableWidth {
            segmentedSurface
                .frame(maxWidth: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                segmentedSurface
                    .fixedSize(horizontal: true, vertical: false)
            }
            .scrollClipDisabled()
        }
    }

    private var segmentedSurface: some View {
        GlassEffectContainer(spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    button(for: option, glassID: index)
                }
            }
            .padding(4)
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 13))
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private func button(for option: Option, glassID: Int) -> some View {
        let isSelected = selection == option

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selection = option
            }
        } label: {
            label(option)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minWidth: minimumSegmentWidth, maxWidth: fillsAvailableWidth ? .infinity : nil)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .glassEffect(
                        .regular.tint(tint(option).opacity(0.30)).interactive(),
                        in: .rect(cornerRadius: 9)
                    )
                    .glassEffectID(glassID, in: glassNamespace)
            }
        }
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

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
