import SwiftUI

struct HomeMacTimelineFilterDetailContainerView<Content: View>: View {
    let onAvailableTagsChange: () -> Void
    let availableTags: [String]
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .onChange(of: availableTags) { _, _ in
                onAvailableTagsChange()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
