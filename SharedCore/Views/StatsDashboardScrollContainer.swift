import SwiftUI

struct StatsDashboardScrollContainer<Content: View>: View {
    let pageBackground: LinearGradient
    let horizontalPadding: CGFloat
    let topPadding: CGFloat
    let bottomPadding: CGFloat
    let maxContentWidth: CGFloat?
    let content: Content

    init(
        pageBackground: LinearGradient,
        horizontalPadding: CGFloat = 20,
        topPadding: CGFloat = 12,
        bottomPadding: CGFloat,
        maxContentWidth: CGFloat?,
        @ViewBuilder content: () -> Content
    ) {
        self.pageBackground = pageBackground
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.maxContentWidth = maxContentWidth
        self.content = content()
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            content
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(pageBackground.ignoresSafeArea())
    }
}
