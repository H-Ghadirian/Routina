import SwiftUI

struct HomeMacFilterDetailContainerView<Content: View>: View {
    let title: String
    let description: String
    let clearButtonTitle: String
    let showsClearButton: Bool
    let onClear: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.largeTitle.weight(.semibold))

                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if showsClearButton {
                        Button(clearButtonTitle, action: onClear)
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }

                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
