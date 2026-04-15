import SwiftUI

struct HomeMacTimelineFilterDetailContainerView<Content: View>: View {
    let showsClearButton: Bool
    let onClear: () -> Void
    let onAvailableTagsChange: () -> Void
    let availableTags: [String]
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Done Filters")
                            .font(.largeTitle.weight(.semibold))

                        Text("Refine the done history in the sidebar by date range and type. Search applies to done entries while Timeline is open.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if showsClearButton {
                        Button("Clear Filters", action: onClear)
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
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
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
