import SwiftUI

private enum HomeMacFilterDetailContainerLayout {
    static let regularPadding: CGFloat = 24
    static let compactHorizontalPadding: CGFloat = 16
    static let compactWidthThreshold: CGFloat = 460
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
