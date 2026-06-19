import SwiftUI

struct HomeMacTimelineFilterDetailContainerView<Content: View>: View {
    let title: String
    let showsTitle: Bool
    let onAvailableTagsChange: () -> Void
    let availableTags: [String]
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        showsTitle: Bool = true,
        onAvailableTagsChange: @escaping () -> Void,
        availableTags: [String],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showsTitle = showsTitle
        self.onAvailableTagsChange = onAvailableTagsChange
        self.availableTags = availableTags
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
            .onChange(of: availableTags) { _, _ in
                onAvailableTagsChange()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
