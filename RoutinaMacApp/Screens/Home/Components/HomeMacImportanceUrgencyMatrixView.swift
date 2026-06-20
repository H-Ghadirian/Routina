import SwiftUI

struct HomeMacCollapsibleFilterSection<Content: View>: View {
    let title: String
    let summaryText: String
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: () -> Content
    @State private var isExpanded = false
    @State private var contentHeight: CGFloat = 0

    init(
        title: String,
        summaryText: String = "",
        systemImage: String = "slider.horizontal.3",
        tint: Color = .accentColor,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.summaryText = summaryText
        self.systemImage = systemImage
        self.tint = tint
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
        .padding(14)
        .routinaGlassPanel(
            cornerRadius: 18,
            tint: tint,
            tintOpacity: isExpanded ? 0.10 : 0.08
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(isExpanded ? 0.28 : 0.18), lineWidth: 1)
        )
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
        HStack(spacing: 10) {
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 14)

            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(tint.opacity(0.16))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
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
            summaryText: summaryText,
            systemImage: "square.grid.2x2",
            tint: .orange
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
