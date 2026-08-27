import SwiftUI

private enum HomeMacFilterDetailContainerLayout {
    static let regularPadding: CGFloat = 24
    static let compactHorizontalPadding: CGFloat = 16
    static let compactWidthThreshold: CGFloat = 460
}

enum HomeMacFilterDetailLayout: Equatable {
    case compact
    case wide

    private static let wideWidthThreshold: CGFloat = 760

    init(availableWidth: CGFloat) {
        self = availableWidth >= Self.wideWidthThreshold ? .wide : .compact
    }

    var fillsAvailableWidth: Bool {
        self == .wide
    }

    var usesCompactPickers: Bool {
        self == .compact
    }
}

private struct HomeMacFilterDetailLayoutKey: EnvironmentKey {
    static let defaultValue = HomeMacFilterDetailLayout.compact
}

extension EnvironmentValues {
    var homeMacFilterDetailLayout: HomeMacFilterDetailLayout {
        get { self[HomeMacFilterDetailLayoutKey.self] }
        set { self[HomeMacFilterDetailLayoutKey.self] = newValue }
    }
}

struct HomeMacAdaptiveFilterChoiceControl<Option: Hashable, OptionLabel: View>: View {
    @Environment(\.homeMacFilterDetailLayout) private var filterLayout

    let accessibilityLabel: String
    let options: [Option]
    let selection: Binding<Option>
    let minimumSegmentWidth: CGFloat
    let usesPickerInCompactLayout: Bool
    let compactPickerFillsAvailableWidth: Bool
    @ViewBuilder let label: (Option) -> OptionLabel

    init(
        accessibilityLabel: String,
        options: [Option],
        selection: Binding<Option>,
        minimumSegmentWidth: CGFloat = 68,
        usesPickerInCompactLayout: Bool = true,
        compactPickerFillsAvailableWidth: Bool = true,
        @ViewBuilder label: @escaping (Option) -> OptionLabel
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        self.selection = selection
        self.minimumSegmentWidth = minimumSegmentWidth
        self.usesPickerInCompactLayout = usesPickerInCompactLayout
        self.compactPickerFillsAvailableWidth = compactPickerFillsAvailableWidth
        self.label = label
    }

    var body: some View {
        if filterLayout.usesCompactPickers && usesPickerInCompactLayout {
            Picker(selection: selection) {
                ForEach(options, id: \.self) { option in
                    label(option)
                        .tag(option)
                }
            } label: {
                Text(accessibilityLabel)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.large)
            .fixedSize(horizontal: !compactPickerFillsAvailableWidth, vertical: false)
            .frame(
                maxWidth: compactPickerFillsAvailableWidth ? .infinity : nil,
                alignment: compactPickerFillsAvailableWidth ? .leading : .trailing
            )
            .accessibilityLabel(accessibilityLabel)
        } else {
            RoutinaGlassSegmentedControl(
                accessibilityLabel: accessibilityLabel,
                options: options,
                selection: selection,
                minimumSegmentWidth: minimumSegmentWidth,
                fillsAvailableWidth: true,
                label: label
            )
        }
    }
}

struct HomeMacFilterDetailContainerView<Content: View>: View {
    let title: String
    let showsTitle: Bool
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        showsTitle: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showsTitle = showsTitle
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = HomeMacFilterDetailLayout(availableWidth: proxy.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showsTitle {
                        HomeMacFilterDetailTitleView(title: title)
                    }
                    content()
                }
                .padding(.horizontal, horizontalPadding(for: proxy.size.width))
                .padding(.vertical, HomeMacFilterDetailContainerLayout.regularPadding)
                .frame(width: proxy.size.width, alignment: .topLeading)
                .environment(\.homeMacFilterDetailLayout, layout)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width <= HomeMacFilterDetailContainerLayout.compactWidthThreshold
            ? HomeMacFilterDetailContainerLayout.compactHorizontalPadding
            : HomeMacFilterDetailContainerLayout.regularPadding
    }
}

struct HomeMacFilterDetailTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.semibold))
            .accessibilityAddTraits(.isHeader)
    }
}
