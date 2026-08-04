import SwiftUI

enum RoutinaSegmentedControlSurfaceStyle: Equatable, Sendable {
    case glass
    case scrolling
}

private struct RoutinaSegmentedControlSurfaceStyleKey: EnvironmentKey {
    static let defaultValue = RoutinaSegmentedControlSurfaceStyle.glass
}

extension EnvironmentValues {
    var routinaSegmentedControlSurfaceStyle: RoutinaSegmentedControlSurfaceStyle {
        get { self[RoutinaSegmentedControlSurfaceStyleKey.self] }
        set { self[RoutinaSegmentedControlSurfaceStyleKey.self] = newValue }
    }
}

struct RoutinaGlassSegmentedControl<Option: Hashable, Label: View>: View {
    let accessibilityLabel: String
    let options: [Option]
    let selection: Option
    let onSelect: (Option) -> Void
    let minimumSegmentWidth: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let fillsAvailableWidth: Bool
    let maximumSegmentsPerRow: Int?
    let tint: (Option) -> Color
    let foregroundColor: (Option, Bool) -> Color
    @ViewBuilder let label: (Option) -> Label
    @Environment(\.routinaSegmentedControlSurfaceStyle) private var surfaceStyle
    @Namespace private var glassNamespace

    init(
        accessibilityLabel: String,
        options: [Option],
        selection: Binding<Option>,
        minimumSegmentWidth: CGFloat = 68,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 7,
        fillsAvailableWidth: Bool = false,
        maximumSegmentsPerRow: Int? = nil,
        tint: @escaping (Option) -> Color = { _ in .accentColor },
        foregroundColor: @escaping (Option, Bool) -> Color = { _, isSelected in
            isSelected ? .black.opacity(0.82) : .secondary
        },
        @ViewBuilder label: @escaping (Option) -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        self.selection = selection.wrappedValue
        self.onSelect = { selection.wrappedValue = $0 }
        self.minimumSegmentWidth = minimumSegmentWidth
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.fillsAvailableWidth = fillsAvailableWidth
        self.maximumSegmentsPerRow = maximumSegmentsPerRow
        self.tint = tint
        self.foregroundColor = foregroundColor
        self.label = label
    }

    init(
        accessibilityLabel: String,
        options: [Option],
        selection: Option,
        onSelect: @escaping (Option) -> Void,
        minimumSegmentWidth: CGFloat = 68,
        horizontalPadding: CGFloat = 14,
        verticalPadding: CGFloat = 7,
        fillsAvailableWidth: Bool = false,
        maximumSegmentsPerRow: Int? = nil,
        tint: @escaping (Option) -> Color = { _ in .accentColor },
        foregroundColor: @escaping (Option, Bool) -> Color = { _, isSelected in
            isSelected ? .black.opacity(0.82) : .secondary
        },
        @ViewBuilder label: @escaping (Option) -> Label
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        self.selection = selection
        self.onSelect = onSelect
        self.minimumSegmentWidth = minimumSegmentWidth
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.fillsAvailableWidth = fillsAvailableWidth
        self.maximumSegmentsPerRow = maximumSegmentsPerRow
        self.tint = tint
        self.foregroundColor = foregroundColor
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
        Group {
            if surfaceStyle == .scrolling {
                segmentedContent
                    .padding(4)
                    .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            } else {
                GlassEffectContainer(spacing: 4) {
                    segmentedContent
                        .padding(4)
                        .frame(maxWidth: fillsAvailableWidth ? .infinity : nil)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 13))
                }
            }
        }
        .padding(.vertical, 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .animation(.easeInOut(duration: 0.18), value: selection)
    }

    @ViewBuilder
    private var segmentedContent: some View {
        if let maximumSegmentsPerRow, maximumSegmentsPerRow > 0 {
            let rows = optionRows(maximumSegmentsPerRow: maximumSegmentsPerRow)
            VStack(spacing: 4) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: 4) {
                        ForEach(rows[rowIndex], id: \.option) { item in
                            button(for: item.option, glassID: item.index)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 4) {
                ForEach(Array(options.enumerated()), id: \.element) { index, option in
                    button(for: option, glassID: index)
                }
            }
        }
    }

    private func optionRows(maximumSegmentsPerRow: Int) -> [[IndexedOption]] {
        Array(options.enumerated()).reduce(into: [[IndexedOption]]()) { rows, pair in
            if rows.last?.count == maximumSegmentsPerRow || rows.isEmpty {
                rows.append([])
            }
            rows[rows.count - 1].append(IndexedOption(index: pair.offset, option: pair.element))
        }
    }

    private func button(for option: Option, glassID: Int) -> some View {
        let isSelected = selection == option

        return Button {
            onSelect(option)
        } label: {
            label(option)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .allowsTightening(true)
                .foregroundStyle(resolvedForegroundColor(for: option, isSelected: isSelected))
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .frame(minWidth: minimumSegmentWidth, maxWidth: fillsAvailableWidth ? .infinity : nil)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                if surfaceStyle == .scrolling {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(tint(option).opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(tint(option).opacity(0.45), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .glassEffect(
                            .regular.tint(tint(option).opacity(0.30)).interactive(),
                            in: .rect(cornerRadius: 9)
                        )
                        .glassEffectID(glassID, in: glassNamespace)
                }
            }
        }
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func resolvedForegroundColor(for option: Option, isSelected: Bool) -> Color {
        guard surfaceStyle == .scrolling else {
            return foregroundColor(option, isSelected)
        }
        return isSelected ? tint(option) : .secondary
    }

    private struct IndexedOption: Hashable {
        let index: Int
        let option: Option
    }
}

extension View {
    func routinaSegmentedControlSurfaceStyle(
        _ style: RoutinaSegmentedControlSurfaceStyle
    ) -> some View {
        environment(\.routinaSegmentedControlSurfaceStyle, style)
    }

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

    func routinaScrollingRoundedFill(
        cornerRadius: CGFloat,
        tint: Color,
        tintOpacity: Double
    ) -> some View {
        background(
            tint.opacity(tintOpacity),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func routinaScrollingPillFill(
        tint: Color,
        tintOpacity: Double
    ) -> some View {
        background(tint.opacity(tintOpacity), in: Capsule())
            .contentShape(Capsule())
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
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
                    .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else if let tint {
            glassEffect(
                .regular.tint(tint.opacity(tintOpacity)),
                in: .rect(cornerRadius: cornerRadius)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}
