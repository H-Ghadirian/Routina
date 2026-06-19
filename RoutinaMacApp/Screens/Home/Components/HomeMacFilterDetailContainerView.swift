import SwiftUI

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
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if showsTitle {
                    HomeMacFilterDetailTitleView(title: title)
                }
                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
