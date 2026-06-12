import SwiftUI

struct HomeMacCollapsibleFilterSection<Content: View>: View {
    let title: String
    let summaryText: String
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0

    init(
        title: String,
        summaryText: String = "",
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.summaryText = summaryText
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                toggleExpanded()
            } label: {
                disclosureHeader
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            collapsibleContent
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var collapsibleContent: some View {
        content()
            .padding(.top, 12)
            .padding(.horizontal, 4)
            .fixedSize(horizontal: false, vertical: true)
            .background(contentHeightReader)
            .frame(height: isExpanded ? contentHeight : 0, alignment: .top)
            .opacity(isExpanded ? 1 : 0)
            .clipped()
            .accessibilityHidden(!isExpanded)
            .animation(.snappy(duration: 0.22), value: isExpanded)
    }

    private var contentHeightReader: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(
                    key: HomeMacCollapsibleFilterSectionHeightPreferenceKey.self,
                    value: proxy.size.height
                )
        }
        .onPreferenceChange(HomeMacCollapsibleFilterSectionHeightPreferenceKey.self) { height in
            guard abs(height - contentHeight) > 0.5 else { return }
            contentHeight = height
        }
    }

    private var disclosureHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if !isExpanded && !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func toggleExpanded() {
        withAnimation(.snappy(duration: 0.22)) {
            isExpanded.toggle()
        }
    }
}

private struct HomeMacCollapsibleFilterSectionHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct HomeMacImportanceUrgencyDisclosureSection: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    let summaryText: String

    var body: some View {
        HomeMacCollapsibleFilterSection(
            title: "Importance & Urgency",
            summaryText: summaryText
        ) {
            HomeMacImportanceUrgencyMatrixView(
                selectedFilter: $selectedFilter,
                summaryText: summaryText
            )
        }
    }
}

struct HomeMacImportanceUrgencyMatrixView: View {
    @Binding var selectedFilter: ImportanceUrgencyFilterCell?
    let summaryText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(selectedFilter == nil ? "All levels selected" : "Show all levels") {
                selectedFilter = nil
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selectedFilter == nil ? Color.accentColor : Color.primary)

            ImportanceUrgencyMatrixPicker(selectedFilter: $selectedFilter)
                .frame(maxWidth: 420, alignment: .leading)

            Text(summaryText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
