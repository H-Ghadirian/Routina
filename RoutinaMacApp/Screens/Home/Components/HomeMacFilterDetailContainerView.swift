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

enum HomeMacFilterControlLayout {
    static let compactPickerWidth: CGFloat = 156
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
    let compactPickerWidth: CGFloat?
    @ViewBuilder let label: (Option) -> OptionLabel

    init(
        accessibilityLabel: String,
        options: [Option],
        selection: Binding<Option>,
        minimumSegmentWidth: CGFloat = 68,
        usesPickerInCompactLayout: Bool = true,
        compactPickerWidth: CGFloat? = nil,
        @ViewBuilder label: @escaping (Option) -> OptionLabel
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        self.selection = selection
        self.minimumSegmentWidth = minimumSegmentWidth
        self.usesPickerInCompactLayout = usesPickerInCompactLayout
        self.compactPickerWidth = compactPickerWidth
        self.label = label
    }

    var body: some View {
        if filterLayout.usesCompactPickers && usesPickerInCompactLayout {
            compactMenuPicker
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

    @ViewBuilder
    private var compactMenuPicker: some View {
        if let compactPickerWidth {
            menuPicker
                .frame(width: compactPickerWidth, alignment: .leading)
        } else {
            menuPicker
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var menuPicker: some View {
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
        .accessibilityLabel(accessibilityLabel)
    }
}

struct HomeMacAdaptiveFilterControlRow<Content: View>: View {
    @Environment(\.homeMacFilterDetailLayout) private var filterLayout

    let title: String
    let pairsInCompactLayout: Bool
    @ViewBuilder let content: () -> Content

    init(
        _ title: String,
        pairsInCompactLayout: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.pairsInCompactLayout = pairsInCompactLayout
        self.content = content
    }

    var body: some View {
        if filterLayout.usesCompactPickers && pairsInCompactLayout {
            HStack(alignment: .center, spacing: 12) {
                controlTitle
                    .frame(maxWidth: .infinity, alignment: .leading)

                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                controlTitle
                content()
            }
        }
    }

    private var controlTitle: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
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
